#!/usr/bin/env python3
"""
Brightspace triage priority algorithm.

Reads a JSON payload on stdin describing courses + assignments + user prefs.
Writes a ranked JSON list on stdout.

The score has four factors multiplied together (urgency, weight, risk), divided
by estimated effort. Intentionally simple — tune the constants at the top of
this file rather than reaching for a more elaborate model.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Tunable constants — edit here to adjust behavior.
# ---------------------------------------------------------------------------

DEFAULT_TARGET_GRADE = 90.0  # Percent. Used when user config is absent.

# Urgency curve: piecewise, in days-until-due (dt).
# Values chosen so the top of the list always skews toward "due soon" without
# completely drowning out medium-term large-weight items.
URGENCY_OVERDUE = 10.0      # dt < -0.5 (>12h late)
URGENCY_DUE_SOON_MAX = 6.0  # dt ~ 0
URGENCY_DUE_SOON_MIN = 1.0  # dt ~ 1 day
URGENCY_WEEK_MAX = 2.0      # dt ~ 1 day
URGENCY_WEEK_MIN = 1.0      # dt ~ 7 days
URGENCY_MONTH_MAX = 1.0     # dt ~ 7 days
URGENCY_MONTH_MIN = 0.5     # dt ~ 21 days
URGENCY_FAR = 0.3           # dt > 21 days

# Risk multiplier: amplifies items in courses where the user is below target.
# At `gap` = RISK_GAP_FULL, multiplier hits 2x.
RISK_GAP_FULL = 20.0

# Weight factor: how much a single assignment can move the final grade.
# Normalized by WEIGHT_DIVISOR so typical scores land in single-digit territory.
WEIGHT_DIVISOR = 10.0

# Default effort-in-hours per category when user hasn't set overrides.
DEFAULT_EFFORT_HOURS: dict[str, float] = {
    "homework": 3.0,
    "hw": 3.0,
    "assignment": 3.0,
    "exam": 8.0,
    "midterm": 8.0,
    "final": 15.0,
    "quiz": 1.0,
    "reading": 2.0,
    "discussion": 0.5,
    "project": 10.0,
    "lab": 3.0,
    "paper": 8.0,
}
FALLBACK_EFFORT_HOURS = 3.0


# ---------------------------------------------------------------------------

@dataclass
class Course:
    name: str
    current_grade: float | None
    category_weights: dict[str, float]      # category name -> % of final
    effort_defaults: dict[str, float]       # category -> hours


@dataclass
class Assignment:
    course: str
    name: str
    category: str
    due: datetime | None
    points_possible: float
    points_earned: float | None
    submitted: bool
    effort_hours: float | None


def parse_iso(s: str | None) -> datetime | None:
    if not s:
        return None
    # Accept trailing Z as UTC.
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def load_user_config(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    p = Path(path).expanduser()
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError as e:
        # Fail loud rather than silently drop user tuning.
        print(f"warning: could not parse {p}: {e}", file=sys.stderr)
        return {}


def course_from_payload(
    course_data: dict[str, Any],
    user_config: dict[str, Any],
) -> Course:
    name = course_data["name"]
    per_course = user_config.get("courses", {}).get(name, {})
    return Course(
        name=name,
        current_grade=course_data.get("current_grade"),
        category_weights=per_course.get("weights", {}),
        effort_defaults=per_course.get("effort_defaults", {}),
    )


def urgency(dt_days: float) -> float:
    if dt_days < -0.5:
        return URGENCY_OVERDUE
    if dt_days < 1:
        # Linear 6.0 -> 1.0 over (0, 1) days. Hits 6.0 at the due moment.
        return URGENCY_DUE_SOON_MAX - (URGENCY_DUE_SOON_MAX - URGENCY_DUE_SOON_MIN) * max(0.0, dt_days)
    if dt_days < 7:
        # Linear 2.0 -> 1.0 over (1, 7) days.
        return URGENCY_WEEK_MAX - (URGENCY_WEEK_MAX - URGENCY_WEEK_MIN) * (dt_days - 1) / 6.0
    if dt_days < 21:
        return URGENCY_MONTH_MAX - (URGENCY_MONTH_MAX - URGENCY_MONTH_MIN) * (dt_days - 7) / 14.0
    return URGENCY_FAR


def weight_factor(
    a: Assignment,
    course: Course,
) -> float:
    """Proxy for how much this assignment can move the final grade.

    If we know the category's weight (from user config), multiply points_possible
    by category_weight_fraction. If we don't, fall back to just points_possible
    (a crude proxy — but strictly monotonic, which is what matters for ranking).
    """
    fraction = course.category_weights.get(a.category, None)
    if fraction is None:
        # No config → just use points.
        return a.points_possible / WEIGHT_DIVISOR
    return (a.points_possible * (fraction / 100.0)) / WEIGHT_DIVISOR


def risk_multiplier(course: Course, target: float) -> float:
    if course.current_grade is None:
        # Unknown grade → neutral.
        return 1.0
    gap = max(0.0, target - course.current_grade)
    return 1.0 + gap / RISK_GAP_FULL


def effort_hours(a: Assignment, course: Course, user_config: dict[str, Any]) -> float:
    if a.effort_hours is not None:
        return max(0.5, a.effort_hours)
    # Precedence: per-course override > user global override > built-in default.
    cat = a.category.lower()
    if cat in course.effort_defaults:
        return max(0.5, course.effort_defaults[cat])
    global_defaults = user_config.get("global_effort_defaults", {})
    if cat in global_defaults:
        return max(0.5, global_defaults[cat])
    return DEFAULT_EFFORT_HOURS.get(cat, FALLBACK_EFFORT_HOURS)


def score_assignment(
    a: Assignment,
    course: Course,
    now: datetime,
    target: float,
    user_config: dict[str, Any],
) -> tuple[float, str]:
    """Return (score, reasoning_string)."""
    if a.submitted:
        return 0.0, "submitted"
    if a.due is None:
        # No due date → low priority by default, but don't zero it out.
        return 0.1, "no due date"

    dt_days = (a.due - now).total_seconds() / 86400.0
    u = urgency(dt_days)
    w = weight_factor(a, course)
    r = risk_multiplier(course, target)
    e = effort_hours(a, course, user_config)

    score = (u * w * r) / e

    # Compact reasoning blurb — explains why this rank.
    parts: list[str] = []
    if dt_days < 0:
        parts.append(f"OVERDUE by {-dt_days:.1f}d")
    elif dt_days < 1:
        parts.append(f"due in {dt_days * 24:.0f}h")
    else:
        parts.append(f"due in {dt_days:.1f}d")

    weight_pct = course.category_weights.get(a.category)
    if weight_pct is not None:
        share = a.points_possible * (weight_pct / 100.0)
        parts.append(f"~{share:.1f}% weight")
    else:
        parts.append(f"{a.points_possible:g} pts (weight unknown)")

    if course.current_grade is not None:
        gap = target - course.current_grade
        if gap > 0:
            parts.append(f"{gap:.0f}pt below target")
        elif gap < -5:
            parts.append(f"{-gap:.0f}pt cushion")

    parts.append(f"{e:.1f}h effort")

    return score, " | ".join(parts)


def course_short_name(name: str) -> str:
    """Crude short form — first token pair: 'CS 23200 Intro...' -> 'CS 23200'."""
    tokens = name.split()
    if len(tokens) >= 2 and any(c.isdigit() for c in tokens[1]):
        return f"{tokens[0]} {tokens[1]}"
    return tokens[0] if tokens else name


def main() -> int:
    payload = json.load(sys.stdin)

    user_config = load_user_config(payload.get("config_path"))
    target = (
        payload.get("target_grade")
        or user_config.get("target_grade")
        or DEFAULT_TARGET_GRADE
    )
    now = parse_iso(payload["now"]) if payload.get("now") else datetime.now(timezone.utc)
    if now is None:
        now = datetime.now(timezone.utc)

    courses_by_name: dict[str, Course] = {}
    for c in payload.get("courses", []):
        course = course_from_payload(c, user_config)
        courses_by_name[course.name] = course

    ranked: list[dict[str, Any]] = []
    for a in payload.get("assignments", []):
        course = courses_by_name.get(a["course"])
        if course is None:
            # Assignment references a course we weren't given. Create a
            # minimal placeholder so we still score something.
            course = Course(
                name=a["course"],
                current_grade=None,
                category_weights={},
                effort_defaults={},
            )

        assn = Assignment(
            course=a["course"],
            name=a["name"],
            category=(a.get("category") or "").lower() or "assignment",
            due=parse_iso(a.get("due")),
            points_possible=float(a.get("points_possible") or 0),
            points_earned=a.get("points_earned"),
            submitted=bool(a.get("submitted", False)),
            effort_hours=a.get("effort_hours"),
        )

        score, reasoning = score_assignment(assn, course, now, target, user_config)
        if score <= 0 and assn.submitted:
            continue
        ranked.append(
            {
                "name": assn.name,
                "course": course_short_name(assn.course),
                "course_full": assn.course,
                "category": assn.category,
                "priority_score": round(score, 2),
                "due": a.get("due"),
                "points_possible": assn.points_possible,
                "reasoning": reasoning,
            }
        )

    ranked.sort(key=lambda x: x["priority_score"], reverse=True)

    json.dump({"ranked": ranked, "target_grade": target}, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
