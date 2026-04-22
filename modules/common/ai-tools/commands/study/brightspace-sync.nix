let
  commandName = "brightspace-sync";
  description = "Pull syllabi from all Brightspace courses and update ~/.config/brightspace-triage/config.json";
  prompt = ''
    Sync grade-category weights from course syllabi into the triage config.

    **Goal:** populate `~/.config/brightspace-triage/config.json` so the
    prioritize algorithm can weight assignments by their real share of the
    final grade, rather than falling back to raw `points_possible`.

    **Steps:**

    1. List enrolled courses via `get_my_courses`.

    2. For each course, fetch the syllabus. Prefer `get_syllabus`; fall back to
       `get_course_content` if the syllabus lives as a module/file rather than
       the dedicated syllabus endpoint. If no syllabus is available, skip the
       course and note it in the summary at the end.

    3. Extract grade category weights from each syllabus. Categories you care
       about (normalize to these lowercase names):

       - `homework` / `assignment` → map to `homework`
       - `exam` / `midterm` → map to `exam` (keep `final` separate when present)
       - `final` → `final`
       - `quiz` → `quiz`
       - `project` → `project`
       - `lab` → `lab`
       - `discussion` / `participation` → `discussion`
       - `paper` / `essay` → `paper`

       If the syllabus uses a category name that doesn't map, keep the
       syllabus's original name — the algorithm will fall back to defaults for
       unknown categories, but it's better than discarding the info.

    4. **Sanity-check the extraction per course:**
       - Weights should sum to 100 (±2 for rounding).
       - If they sum to something else, surface the discrepancy — common
         reasons: extra credit, late-policy buffers, stated-but-not-computed
         categories. Ask the user whether to renormalize or record as-is.
       - If you can't find weights at all (syllabus is prose without
         percentages), say so — don't invent numbers.

    5. **Load the existing config** at `~/.config/brightspace-triage/config.json`
       if it exists. Parse it. You are MERGING, not overwriting.

       Merge rules:
       - Preserve `target_grade` if set.
       - Preserve `global_effort_defaults` if set.
       - Preserve any `effort_defaults` under a course (user-tuned).
       - Replace `weights` under a course only if the syllabus gave you new
         ones AND they differ from what's stored. Never delete weights the
         user has but the syllabus doesn't mention.
       - Add new courses that weren't in the old config.

    6. **Show a diff before writing.** Render as a markdown table:

       ```
       | Course    | Category  | Old | New |
       |-----------|-----------|-----|-----|
       | CS 23200  | homework  | —   | 30  |
       | CS 23200  | exam      | —   | 50  |
       ```

       Use `—` for "not set." Group additions, changes, and unchanged
       entries separately. Include a row count summary.

    7. **Ask for confirmation** before writing. Do not auto-commit. On yes,
       write to `~/.config/brightspace-triage/config.json` with indent=2. If
       the file already exists, make a `.bak` copy alongside it first.

       Use this Python one-liner for the write (or equivalent Bash) — invoke
       via the Bash tool, do not reconstruct JSON in prose:

       ```
       python3 -c 'import json, shutil, pathlib, sys; p=pathlib.Path.home()/".config/brightspace-triage/config.json"; p.parent.mkdir(parents=True, exist_ok=True); p.exists() and shutil.copy(p, p.with_suffix(".json.bak")); p.write_text(json.dumps(json.load(sys.stdin), indent=2) + "\n")' <<EOF
       { ...merged config... }
       EOF
       ```

    8. **Report back** with a short summary: N courses synced, M weights
       updated, K courses skipped (and why).

    **Guardrails:**
    - Never write a config with a `weights` object where the numbers are
      obviously wrong (e.g. all zeros, negatives, anything > 100).
    - If a syllabus parse is ambiguous, prefer leaving weights blank over
      guessing. The algorithm degrades gracefully; a wrong weight is worse
      than a missing one.
    - If the Brightspace MCP session is stale, stop and tell the user to
      re-run `brightspace-auth`. Don't try to patch around auth errors.
    - This command is idempotent — re-running without syllabus changes should
      produce "no changes" and exit without writing.
  '';
in
{
  ${commandName} = {
    inherit
      commandName
      description
      prompt
      ;
  };
}
