"""Scout for Pat's X reply funnel.

Runs as a Hermes cron script every 5 minutes, 1 to 9pm ET. Polls the approved
targets in /var/lib/hermes/x/targets.md through twitterapi.io, keeps fresh
posts that are still worth replying to, applies the daily quotas and pacing,
and prints either {"wakeAgent": false} (no model run) or a JSON line with the
posts the drafting agent should write replies for.

Read-only against X: never follows, likes or posts. Stdlib only.
Needs TWITTERAPI_IO_KEY in the environment.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo

    ET = ZoneInfo("America/New_York")
except (ImportError, KeyError):
    ET = timezone(timedelta(hours=-4))

API = "https://api.twitterapi.io/twitter"
CREDITS_PER_TWEET = 15  # $0.15 per 1k tweets; an empty call bills one tweet
DIR = os.environ.get("X_DIR", "/var/lib/hermes/x")
TARGETS = f"{DIR}/targets.md"
STATE = f"{DIR}/scout-state.json"

WINDOW_ET = (13, 21)  # drafts only 1pm to 9pm ET
MAX_AGE_MIN = 60  # older posts are stale
MAX_REPLIES = 30  # busier threads bury Pat's reply
EXPIRY_H = 2  # a draft expires 2h after the post
PACE_WINDOW_MIN = 30
PACE_MAX = 3  # at most 3 drafts per 30 minutes
QUOTA_WEEKDAY = {"A": 6, "B": 5, "C": 4}  # 15 a day
QUOTA_WEEKEND = {"A": 3, "B": 3, "C": 2}  # 8 a day
OPEN_QUOTAS_AT_ET = 18  # from 6pm, unused allowance opens to any tier
HANDLES_PER_QUERY = 16  # keeps each from: query well under the length limit
PAGES_PER_QUERY = 2


def load_targets(path):
    tiers, tier = {}, None
    with open(path) as f:
        for line in f:
            m = re.match(r"## Tier ([ABC])", line)
            if m:
                tier = m.group(1)
            elif line.startswith("## "):
                tier = None
            elif tier and (m := re.match(r"- @(\w+)", line)):
                tiers[m.group(1).lower()] = (m.group(1), tier)
    if not tiers:
        sys.exit(f"no targets parsed from {path}")
    return tiers


def load_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def save_state(state):
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1)
    os.replace(tmp, STATE)


def get(path, params, key):
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"X-API-Key": key})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.load(resp)
        except urllib.error.HTTPError as err:
            if err.code == 429 and attempt < 3:
                time.sleep(2 * 2**attempt)
                continue
            raise
    return {}


def parse_time(s):
    return datetime.strptime(s, "%a %b %d %H:%M:%S %z %Y")


def fetch(handles, since, key):
    """Original posts from the handles since a unix time, plus credits spent."""
    posts, credits = [], 0
    for i in range(0, len(handles), HANDLES_PER_QUERY):
        froms = " OR ".join(f"from:{h}" for h in handles[i : i + HANDLES_PER_QUERY])
        query = f"({froms}) -filter:replies -filter:retweets since_time:{since}"
        cursor = ""
        for _ in range(PAGES_PER_QUERY):
            data = get(
                "tweet/advanced_search",
                {"query": query, "queryType": "Latest", "cursor": cursor},
                key,
            )
            tweets = data.get("tweets") or []
            credits += CREDITS_PER_TWEET * max(len(tweets), 1)
            posts.extend(tweets)
            if not data.get("has_next_page") or not tweets:
                break
            cursor = data.get("next_cursor") or ""
    return posts, credits


def candidate(t, targets, now, max_age):
    """Slim record for a post worth drafting on, or None."""
    author = ((t.get("author") or {}).get("userName") or "").lower()
    if author not in targets or not t.get("id") or not t.get("createdAt"):
        return None
    if t.get("isReply") or t.get("retweeted_tweet") or t.get("isLimitedReply"):
        return None
    created = parse_time(t["createdAt"])
    if (now - created).total_seconds() / 60 > max_age:
        return None
    if (t.get("replyCount") or 0) >= MAX_REPLIES:
        return None
    handle, tier = targets[author]
    return {
        "id": str(t["id"]),
        "handle": handle,
        "tier": tier,
        "url": t.get("url") or f"https://x.com/{handle}/status/{t['id']}",
        "text": (t.get("text") or "")[:200],
        "created_at": created.isoformat(),
        "replies": t.get("replyCount") or 0,
        "likes": t.get("likeCount") or 0,
        "views": t.get("viewCount") or 0,
        "quote_of": ((t.get("quoted_tweet") or {}).get("text") or "")[:200] or None,
    }


def pick(pool, day, now_et, slots, quotas):
    """Choose posts to draft now under quotas, one per account per day."""
    used = day["tiers"]
    total_left = sum(quotas.values()) - sum(used.values())
    open_quotas = now_et.hour >= OPEN_QUOTAS_AT_ET
    # Quieter threads first (in steps of 5 replies), then freshest
    ranked = sorted(
        pool,
        key=lambda c: (c["replies"] // 5, -datetime.fromisoformat(c["created_at"]).timestamp()),
    )
    chosen = []
    for c in ranked:
        if len(chosen) >= min(slots, total_left):
            break
        h = c["handle"].lower()
        if h in day["accounts"] or any(x["handle"].lower() == h for x in chosen):
            continue
        tier_used = used.get(c["tier"], 0) + sum(x["tier"] == c["tier"] for x in chosen)
        if tier_used < quotas[c["tier"]] or open_quotas:
            chosen.append(c)
    return chosen


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--dry-run", action="store_true", help="ignore hours and pacing, save no state")
    ap.add_argument("--max-age", type=int, default=MAX_AGE_MIN, help="minutes")
    ap.add_argument("--limit", type=int, default=PACE_MAX, help="posts per dry run")
    args = ap.parse_args()

    key = os.environ.get("TWITTERAPI_IO_KEY")
    if not key:
        sys.exit("TWITTERAPI_IO_KEY is not set")
    now = datetime.now(timezone.utc)
    now_et = now.astimezone(ET)

    if not args.dry_run and not (WINDOW_ET[0] <= now_et.hour < WINDOW_ET[1]):
        print(json.dumps({"wakeAgent": False}))
        return

    targets = load_targets(TARGETS)
    state = {} if args.dry_run else load_state()
    today = now_et.date().isoformat()
    day = state.setdefault("days", {}).setdefault(today, {"tiers": {}, "accounts": [], "usd": 0.0})

    since = max(int(now.timestamp()) - args.max_age * 60, int(state.get("last_poll", 0)) - 60)
    posts, credits = fetch([h for h, _ in targets.values()], since, key)
    usd = credits / 100_000

    seen = state.setdefault("seen", {})  # post id -> unix time first seen
    pool = {c["id"]: c for c in state.get("pool", [])}
    for t in posts:
        c = candidate(t, targets, now, args.max_age)
        if c and c["id"] not in seen:
            pool[c["id"]] = c
            seen[c["id"]] = int(now.timestamp())
    # Drop pooled posts that went stale while waiting on pacing
    pool = {
        i: c
        for i, c in pool.items()
        if (now - datetime.fromisoformat(c["created_at"])).total_seconds() <= args.max_age * 60
    }

    weekend = now_et.weekday() >= 5
    quotas = QUOTA_WEEKEND if weekend else QUOTA_WEEKDAY
    recent = [ts for ts in state.get("recent_drafts", []) if now.timestamp() - ts < PACE_WINDOW_MIN * 60]
    slots = args.limit if args.dry_run else max(PACE_MAX - len(recent), 0)
    chosen = pick(list(pool.values()), day, now_et, slots, quotas)

    day["usd"] = round(day.get("usd", 0) + usd, 5)
    if not args.dry_run:
        for c in chosen:
            pool.pop(c["id"], None)
            day["tiers"][c["tier"]] = day["tiers"].get(c["tier"], 0) + 1
            day["accounts"].append(c["handle"].lower())
            recent.append(now.timestamp())
        state["last_poll"] = int(now.timestamp())
        state["pool"] = list(pool.values())
        state["recent_drafts"] = recent
        state["seen"] = {i: ts for i, ts in seen.items() if ts > now.timestamp() - 2 * 86400}
        keep = {(now_et.date() - timedelta(days=d)).isoformat() for d in range(40)}
        state["days"] = {d: v for d, v in state["days"].items() if d in keep}
        save_state(state)

    if not chosen:
        print(json.dumps({"wakeAgent": False}))
        return
    for c in chosen:
        exp = (datetime.fromisoformat(c["created_at"]) + timedelta(hours=EXPIRY_H)).astimezone(ET)
        c["expires_et"] = exp.strftime("%-I:%M%p").lower() + " ET"
    month = now_et.strftime("%Y-%m")
    print(
        json.dumps(
            {
                "wakeAgent": True,
                "context": {
                    "dry_run": args.dry_run,
                    "now_et": now_et.strftime("%Y-%m-%d %H:%M ET"),
                    "weekend": weekend,
                    "drafted_today_before_this": {
                        t: n - sum(c["tier"] == t for c in chosen) if not args.dry_run else n
                        for t, n in day["tiers"].items()
                    },
                    "quotas": quotas,
                    "scout_usd_this_tick": round(usd, 5),
                    "scout_usd_this_month": round(
                        sum(v.get("usd", 0) for d, v in state["days"].items() if d.startswith(month)), 4
                    ),
                    "posts": chosen,
                },
            }
        )
    )


if __name__ == "__main__":
    main()
