"""Find X accounts worth replying to for Pat's growth funnel.

Searches niche topics through twitterapi.io, then profiles each promising
author's recent posts to check that real people see and reply to them.
Writes a JSON report for Herm to review. It never follows, likes or posts.

Needs TWITTERAPI_IO_KEY in the environment. Stdlib only.
"""

import argparse
import json
import math
import os
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo

    ET = ZoneInfo("America/New_York")
except (ImportError, KeyError):  # no zoneinfo or no tz database
    ET = timezone(timedelta(hours=-4))

API = "https://api.twitterapi.io/twitter"
# $0.15 per 1k tweets at 100k credits per dollar; empty calls bill one tweet
CREDITS_PER_TWEET = 15
SELF = "patwrall"
DRAFT_HOURS_ET = (13, 21)  # 1pm to 9pm, Pat's drafting window

# Topic searches per tier as (query, min_faves). Each also gets lang:en,
# no replies or reposts, and the lookback window.
QUERIES = {
    "A": [
        # Bare "cuda" and "triton" also match sports and naval accounts, so
        # these two require a second technical term
        (
            '(CUDA OR "GPU kernel" OR "GPU kernels") (GPU OR kernel OR nvcc OR warp OR PTX OR "shared memory")',
            20,
        ),
        (
            '(triton OR cutlass OR "tensor cores" OR flashattention OR "flash attention") (kernel OR GPU OR pytorch OR attention)',
            20,
        ),
        (
            '(vllm OR sglang OR "inference engine" OR "kv cache" OR "speculative decoding")',
            30,
        ),
        (
            '("memory bandwidth" OR roofline OR "arithmetic intensity" OR "memory bound") (GPU OR LLM OR inference)',
            15,
        ),
        (
            '("ML systems" OR mlsys OR "kernel fusion" OR "torch.compile" OR "training run")',
            25,
        ),
        ('(nixos OR nixpkgs OR "nix flake" OR "home-manager")', 15),
        (
            "(H100 OR B200 OR FP8 OR PTX OR quantization) (kernel OR throughput OR latency OR benchmark)",
            20,
        ),
        (
            "(JAX OR XLA OR Pallas OR MLIR OR Mojo) (kernel OR compiler OR performance)",
            20,
        ),
    ],
    "B": [
        (
            '("AI agent" OR "coding agent" OR "AI agents") ("just shipped" OR launched OR "we built" OR shipping)',
            40,
        ),
        (
            '("dev tools" OR devtools OR "developer tools") (founder OR building OR shipped OR launch)',
            30,
        ),
        (
            '("open source" OR "open-source") (LLM OR inference OR agent) (release OR released OR launch)',
            40,
        ),
        ('("Claude Code" OR codex OR cursor) (workflow OR setup OR agents)', 50),
    ],
    # Investors rarely post topic keywords, so match the language of deal posts
    "C": [
        (
            '("we led" OR "excited to back" OR "excited to lead" OR "led the seed" OR "led the pre-seed" OR "our investment in") (AI OR infra OR infrastructure OR "dev tools" OR developer)',
            10,
        ),
        (
            '("portfolio company" OR "our portfolio" OR "first check" OR "backing founders") (AI OR infrastructure OR agents)',
            15,
        ),
        (
            '(VC OR investor OR "we invest") ("AI infra" OR inference OR compute) (thesis OR market OR "why we")',
            20,
        ),
    ],
}

# Share of profiling slots per tier; leftovers go to the best remaining
TIER_SHARE = {"A": 0.5, "B": 0.3, "C": 0.2}


class Budget:
    def __init__(self, usd):
        self.limit = usd * 100_000
        self.spent = 0
        self.calls = 0

    def charge(self, n_tweets):
        self.calls += 1
        self.spent += CREDITS_PER_TWEET * max(n_tweets, 1)

    def left(self):
        return self.spent < self.limit

    @property
    def usd(self):
        return self.spent / 100_000


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


def bio(author):
    pb = author.get("profile_bio")
    from_pb = pb.get("description") if isinstance(pb, dict) else None
    return from_pb or author.get("description") or ""


def search(key, budget, days, pages):
    since = int(time.time()) - days * 86400
    authors = {}
    for tier, queries in QUERIES.items():
        for q, faves in queries:
            query = f"{q} lang:en -filter:replies -filter:retweets min_faves:{faves} since_time:{since}"
            cursor = ""
            for _ in range(pages):
                if not budget.left():
                    return authors
                data = get(
                    "tweet/advanced_search",
                    {"query": query, "queryType": "Latest", "cursor": cursor},
                    key,
                )
                tweets = data.get("tweets") or []
                budget.charge(len(tweets))
                for t in tweets:
                    c = add_candidate(authors, t.get("author") or {}, tier)
                    if c:
                        c["hits"].append(
                            (t.get("likeCount") or 0) + 3 * (t.get("replyCount") or 0)
                        )
                if not data.get("has_next_page"):
                    break
                cursor = data.get("next_cursor") or ""
                time.sleep(0.3)
    return authors


def add_candidate(authors, user, tier):
    handle = (user.get("userName") or "").lower()
    if not handle or handle == SELF:
        return None
    c = authors.setdefault(
        handle,
        {
            "userName": user.get("userName"),
            "name": user.get("name"),
            "followers": user.get("followers") or 0,
            "following": user.get("following") or 0,
            "bio": bio(user),
            "location": user.get("location") or "",
            "automated": bool(user.get("isAutomated")),
            "tiers": set(),
            "hits": [],
        },
    )
    c["tiers"].add(tier)
    return c


def pick_for_profiling(authors, args):
    pool = [
        c
        for c in authors.values()
        if args.min_followers <= c["followers"] <= args.max_followers
        and not c["automated"]
    ]
    for c in pool:
        c["tier_hint"] = min(c["tiers"])
        # Engagement their matching posts earned. Scaling this down by size
        # favored tiny accounts with one lucky post, which then fail the reach
        # check; profile() already rejects accounts too big to reply under.
        c["prelim"] = sum(c["hits"])
    pool.sort(key=lambda c: c["prelim"], reverse=True)
    picked, counts = [], {t: 0 for t in TIER_SHARE}
    for c in pool:
        t = c["tier_hint"]
        if counts[t] < round(args.max_profiles * TIER_SHARE[t]):
            picked.append(c)
            counts[t] += 1
    for c in pool:
        if len(picked) >= args.max_profiles:
            break
        if c not in picked:
            picked.append(c)
    return picked[: args.max_profiles]


def last_tweets(handle, key, budget, include_replies):
    params = {"userName": handle, "includeReplies": str(include_replies).lower()}
    tweets = (get("user/last_tweets", params, key).get("data") or {}).get(
        "tweets"
    ) or []
    budget.charge(len(tweets))
    return [t for t in tweets if t.get("createdAt")]


def profile(c, key, budget, now):
    # Reach and rhythm come from an originals-only feed and talking back from a
    # feed with replies. One mixed feed of 20 hides a heavy replier's posts.
    originals = [
        t
        for t in last_tweets(c["userName"], key, budget, include_replies=False)
        if not t.get("isReply") and not t.get("retweeted_tweet")
    ]
    mixed = last_tweets(c["userName"], key, budget, include_replies=True)
    if not originals and not mixed:
        return None
    times = [parse_time(t["createdAt"]) for t in originals + mixed]
    orig_times = [parse_time(t["createdAt"]) for t in originals] or times
    span_days = max((max(orig_times) - min(orig_times)).total_seconds() / 86400, 1)
    replies = [t for t in mixed if t.get("isReply")]

    def med(field):
        vals = [t.get(field) or 0 for t in originals]
        return statistics.median(vals) if vals else 0

    in_window = [
        t
        for t in originals
        if DRAFT_HOURS_ET[0]
        <= parse_time(t["createdAt"]).astimezone(ET).hour
        < DRAFT_HOURS_ET[1]
    ]
    n_orig = max(len(originals), 1)
    return {
        "originals": len(originals),
        "reply_share": round(len(replies) / max(len(mixed), 1), 2),
        "originals_per_day": round(len(originals) / span_days, 1),
        "median_views": int(med("viewCount")),
        "median_replies": med("replyCount"),
        "median_likes": med("likeCount"),
        "like_rate": round(med("likeCount") / max(c["followers"], 1), 4),
        "hours_since_last": round((now - max(times)).total_seconds() / 3600, 1),
        "window_share": round(len(in_window) / n_orig, 2),
        "limited_reply_share": round(
            sum(1 for t in originals if t.get("isLimitedReply")) / n_orig, 2
        ),
        "samples": [
            {
                "text": (t.get("text") or "")[:200],
                "url": t.get("url"),
                "views": t.get("viewCount"),
                "replies": t.get("replyCount"),
            }
            for t in originals[:3]
        ],
    }


def funnel_problem(p):
    """Why an account can't send Pat followers, or None if it can."""
    if p["hours_since_last"] > 7 * 24:
        return "inactive for a week"
    if p["originals"] < 3:
        return "few original posts"
    if p["originals_per_day"] < 0.3:
        return "posts rarely"
    if p["median_views"] < 1500:
        return "low views"
    if p["median_replies"] < 2:
        return "nobody replies"
    if p["median_replies"] > 80:
        return "replies get buried"
    if p["like_rate"] < 0.001:
        return "dead audience"
    if p["limited_reply_share"] > 0.5:
        return "limits replies"
    return None


def funnel_score(p):
    return round(
        math.log10(max(p["median_views"], 1))
        + 0.5 * math.log10(1 + p["median_replies"])
        + 0.3 * min(p["originals_per_day"], 3)
        + 0.8 * p["reply_share"]  # accounts that talk back
        + 0.5 * p["window_share"]
        - (0.5 if p["median_replies"] > 40 else 0),
        2,
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--budget-usd", type=float, default=2.0)
    ap.add_argument("--max-profiles", type=int, default=200)
    ap.add_argument("--pages", type=int, default=4, help="search pages per topic")
    ap.add_argument("--min-followers", type=int, default=1500)
    ap.add_argument("--max-followers", type=int, default=400_000)
    ap.add_argument("--out", default="/var/lib/hermes/x/discovery.json")
    args = ap.parse_args()

    key = os.environ.get("TWITTERAPI_IO_KEY")
    if not key:
        sys.exit("TWITTERAPI_IO_KEY is not set")
    budget = Budget(args.budget_usd)
    now = datetime.now(timezone.utc)

    authors = search(key, budget, args.days, args.pages)
    picked = pick_for_profiling(authors, args)

    passed, rejected = [], []
    for c in picked:
        if not budget.left():
            break
        p = profile(c, key, budget, now)
        time.sleep(0.3)
        entry = {
            k: c[k]
            for k in (
                "userName",
                "name",
                "followers",
                "following",
                "bio",
                "location",
                "tier_hint",
            )
        }
        entry["tiers_matched"] = sorted(c["tiers"])
        problem = "no recent posts" if p is None else funnel_problem(p)
        if problem:
            # Keep the numbers so near-misses are visible, minus the post samples
            stats = {k: v for k, v in (p or {}).items() if k != "samples"}
            rejected.append({**entry, **stats, "reason": problem})
            continue
        passed.append({**entry, **p, "score": funnel_score(p)})
    passed.sort(key=lambda e: e["score"], reverse=True)

    report = {
        "generated_at": now.isoformat(),
        "cost_usd": round(budget.usd, 4),
        "api_calls": budget.calls,
        "authors_found": len(authors),
        "profiled": len(passed) + len(rejected),
        "passed": passed,
        "rejected": rejected,
    }
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w") as f:
        json.dump(report, f, indent=1)

    print(
        f"found {len(authors)} authors, profiled {report['profiled']}, "
        f"{len(passed)} passed, cost ${report['cost_usd']} over {budget.calls} calls"
    )
    print(
        f"{'handle':<20} tier {'followers':>9} {'views':>7} {'replies':>7} {'orig/d':>6} {'talks':>5} {'window':>6} score"
    )
    for e in passed:
        print(
            f"{e['userName']:<20} {e['tier_hint']:<4} {e['followers']:>9} {e['median_views']:>7} "
            f"{e['median_replies']:>7} {e['originals_per_day']:>6} {e['reply_share']:>5} {e['window_share']:>6} {e['score']}"
        )
    rejected_counts = {}
    for r in rejected:
        rejected_counts[r["reason"]] = rejected_counts.get(r["reason"], 0) + 1
    print(
        "rejected:",
        ", ".join(f"{n} {why}" for why, n in sorted(rejected_counts.items())) or "none",
    )
    print(f"full report: {args.out}")


if __name__ == "__main__":
    main()
