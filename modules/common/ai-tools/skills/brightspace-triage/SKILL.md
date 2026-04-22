---
name: brightspace-triage
description: Query Brightspace (D2L) for grades, due dates, and assignments, then compute and present a prioritized study plan. Use when the user asks what to work on, what's due, how they're doing in a class, or asks for a prioritized to-do list. Also use for formatting grade summaries and weekly planning.
---

# Brightspace Triage

Turn raw Brightspace data into a ranked, explainable study plan.

## When to load

Trigger when the user:
- Asks "what should I work on?" / "what's most important?"
- Asks for grades, deadlines, or upcoming assignments
- Wants a weekly or daily study plan
- Mentions Brightspace, D2L, or a specific course
- Invokes `/grades`, `/week`, or `/prioritize`

## Tools you have

The `brightspace-mcp-server` MCP exposes (names are approximate; discover real ones at runtime):
- `get_my_courses` — enrolled courses
- `get_my_grades` — grades per course (numeric + letter)
- `get_upcoming_due_dates` — deadlines across all courses
- `get_assignments` — assignment list for a course (with points, due, submission status)
- `get_syllabus` — course syllabus (used to extract grade weights)
- `get_announcements`, `get_discussions`, `get_course_content`, `download_file`

Prefer `get_upcoming_due_dates` + `get_my_grades` + `get_assignments` for triage. Batch calls — don't serialize one per course if a single call returns everything.

## The priority algorithm

Do NOT compute priority scores yourself. Always delegate to the bundled script:

```
python3 scripts/prioritize.py < input.json
```

**Why a script:** the algorithm weighs urgency × grade impact × risk ÷ effort. Doing this inline produces inconsistent results; the script produces deterministic, auditable output the user can tune.

**Input shape** (`input.json`):
```json
{
  "target_grade": 90,
  "now": "2026-04-22T05:30:00Z",
  "config_path": "/home/<user>/.config/brightspace-triage/config.json",
  "courses": [
    {
      "name": "CS 23200 Intro to C and UNIX",
      "current_grade": 87.3
    }
  ],
  "assignments": [
    {
      "course": "CS 23200 Intro to C and UNIX",
      "name": "HW5",
      "category": "homework",
      "due": "2026-04-25T23:59:00Z",
      "points_possible": 50,
      "points_earned": null,
      "submitted": false,
      "effort_hours": null
    }
  ]
}
```

Keys you don't know → emit `null` and let the script fall back to defaults.

**Output shape:**
```json
{
  "ranked": [
    {
      "name": "HW5",
      "course": "CS 23200",
      "priority_score": 12.34,
      "due": "2026-04-25T23:59:00Z",
      "reasoning": "due in 3.2d | 5.0% weight | 3pt below target | 3h effort"
    }
  ]
}
```

See `references/algorithm.md` for the full scoring formula and how to tune it.

## User config

Optional file at `~/.config/brightspace-triage/config.json`:

```json
{
  "target_grade": 90,
  "courses": {
    "CS 23200 Intro to C and UNIX": {
      "weights": {"homework": 30, "exams": 50, "final": 20},
      "effort_defaults": {"homework": 4, "exams": 10}
    }
  },
  "global_effort_defaults": {
    "homework": 3, "exam": 8, "quiz": 1, "project": 10,
    "discussion": 0.5, "reading": 2, "final": 15
  }
}
```

If the file doesn't exist, the script uses built-in defaults (target_grade=90, generic effort table). Offer to help the user create/edit it when:
- They ask why a specific item is ranked where it is
- Priorities feel off to them
- They mention category weights from a syllabus

**Bootstrap shortcut:** the `/brightspace-sync` command reads every course's
syllabus via MCP and proposes a merged `config.json` with category weights
extracted. Recommend it the first time you notice the config file is missing,
or when rankings feel consistently off because weights are unknown.

## Formatting the output

**Default to a table**, not a bulleted list. Students scan tables faster.

```
| # | Course    | Assignment | Due            | Points | Score |
|---|-----------|------------|----------------|--------|-------|
| 1 | CS 23200  | HW5        | Fri 11:59pm    |    50  | 12.3  |
```

Include a short "why #1" sentence under the table citing the script's `reasoning` field. Show the top 5–10, not the full list, unless asked.

For a grade summary (`/grades`), group by course with current grade, recent graded items, and a one-line "you're N points from an A" callout.

For weekly view (`/week`), group by day of the week, with scores as a secondary hint.

## Hard rules

- **Never invent numbers.** If a field is missing, show "—" and say so. Don't guess.
- **Always surface assumptions** — if you inferred the target grade (user didn't specify), say so.
- **Don't double-count submitted work** — the script filters submitted items out; if something shows up as submitted in the MCP data, trust that.
- **Gradebook categories vary.** If a course's categories look weird (e.g. "Participation" worth 40%), flag it to the user.
