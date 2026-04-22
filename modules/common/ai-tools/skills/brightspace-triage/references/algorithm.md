# Priority algorithm — detailed reference

## Formula

```
priority = (urgency × weight_factor × risk_multiplier) / effort_hours
```

Four factors, multiplied. Higher is more urgent.

## Urgency (piecewise by days-until-due)

| Range                    | Value          | Notes                         |
|--------------------------|----------------|-------------------------------|
| Overdue (> 12h late)     | `10.0` (flat)  | Dominates everything else     |
| 0–1 day                  | `6.0 → 1.0`    | Linear decay over 24h         |
| 1–7 days                 | `2.0 → 1.0`    | Linear decay over the week    |
| 7–21 days                | `1.0 → 0.5`    | Linear decay over two weeks   |
| > 21 days                | `0.3` (flat)   | Low but nonzero               |

Rationale: a last-minute HW still beats a high-point exam three weeks out, but a
mid-weight item due in 3 days beats a small item due tomorrow. The step at 21
days is deliberate — beyond that, plan but don't panic.

## Weight factor

```
# With known category weights (from user config):
weight_factor = points_possible × (category_weight_pct / 100) / 10

# Without config (fallback):
weight_factor = points_possible / 10
```

The `/10` is a normalization constant so typical scores land in single digits.
It's arbitrary — you can change `WEIGHT_DIVISOR` in the script without changing
the ranking (all scores scale identically).

**When you care about precision:** provide category weights in your user config.
A 50-point homework in a course where HW is 30% of grade moves final by 1.5
percentage points. A 50-point homework in a course where HW is 60% moves it by
3. The algorithm should know which is which.

## Risk multiplier

```
risk = 1.0 + max(0, target_grade - current_grade) / 20
```

At target → 1.0x. 20 points below target → 2.0x. Designed so items in struggling
courses float to the top, but the scale doesn't run away — a course you're
failing gets 2x weight, not 10x.

If `current_grade` is unknown, risk defaults to `1.0` (neutral).

## Effort hours

Precedence (first match wins):
1. The assignment itself has `effort_hours` set (user-provided estimate)
2. Per-course override in user config: `courses.<name>.effort_defaults.<category>`
3. Global override in user config: `global_effort_defaults.<category>`
4. Built-in `DEFAULT_EFFORT_HOURS` table in the script
5. Fallback: 3 hours

Clamped to minimum 0.5 to prevent division blowup on 5-minute tasks.

## Failure modes and how to read them

**"HW5 is top but it's only worth 20 pts, why?"**
Check its due date. Urgency of 6.0 (due tomorrow) times a 2-pt weight can still
beat a 50-pt item due in a week (urgency 1.5). If it feels wrong, either the
effort estimate is too low (bump it in config), or the urgency step is too
aggressive (edit `URGENCY_DUE_SOON_MAX` in the script).

**"Everything from CS 23200 is ranked above my other classes."**
Your current_grade in that course is probably below target_grade. Risk
multiplier is amplifying. Verify by checking the `reasoning` blurb — it'll say
"Npt below target." If you're fine with the grade, raise your `target_grade` or
remove it.

**"The algorithm thinks a discussion post is a 3-hour task."**
Edit `DEFAULT_EFFORT_HOURS` or the user-config equivalent. The defaults are
opinionated; treat them as starting points.

## Things the algorithm intentionally does NOT do

- **Dependency tracking.** If HW5 requires reading chapter 7, the script doesn't
  know. You list both separately.
- **Partial credit modeling.** Assumes you'll either complete an item or skip.
  Doesn't model "60% of full credit is fine."
- **Late-penalty modeling.** Treats deadlines as hard. If your course allows
  late with penalty, the urgency curve overstates post-deadline items.
- **Time-of-day weighting.** Doesn't care whether due at 8am vs 11:59pm, only the day.
- **Study session calendaring.** Doesn't say "do this Tuesday evening." Only
  ranks.

## Tuning tips

1. Start with defaults. Don't tune anything for a week.
2. When a ranking feels wrong, ask yourself *which factor* is off — urgency,
   weight, risk, or effort — and edit that constant only.
3. The user config file is the right place for per-course idiosyncrasies; the
   script is the right place for algorithm-wide changes.
