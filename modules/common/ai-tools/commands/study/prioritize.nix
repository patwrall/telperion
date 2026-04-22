let
  commandName = "prioritize";
  description = "Rank what to work on next using Brightspace data and the triage algorithm";
  argumentHint = "[horizon-days]";
  prompt = ''
    Produce a ranked to-do list drawing from Brightspace.

    **Steps:**

    1. Pull data via the brightspace-mcp-server MCP:
       - `get_upcoming_due_dates` (or equivalent) covering at least the next 21 days, or `$1` days if the user passed an argument
       - `get_my_grades` for all courses, to capture `current_grade`
       - `get_my_courses` if you need course names/ids

       Prefer a single batched call per tool — don't fan out per-course if one call suffices.

    2. Normalize into the input shape expected by `scripts/prioritize.py` (see SKILL.md). For any field that isn't available from the API (e.g. `category`, `effort_hours`), emit `null` and let the script fall back to defaults.

    3. Pipe the JSON into the bundled script and parse the result:

       ```
       python3 <skill>/scripts/prioritize.py < input.json
       ```

       The script is authoritative — don't recompute priority yourself.

    4. Render the top 10 as a markdown table:

       ```
       | # | Course    | Assignment | Due            | Pts | Score |
       |---|-----------|------------|----------------|-----|-------|
       ```

       Below the table, add:
       - One sentence on *why* item #1 ranked where it did (cite its `reasoning` field).
       - A single "Assumptions" line if you inferred target_grade or missing fields.

    5. If any item is overdue, put a warning line above the table.

    **Guardrails:**
    - Never invent data. If `current_grade` isn't available, show `—` and note the assumption.
    - Don't show scores to more than 2 decimal places.
    - If the user's session to Brightspace has expired (MCP calls return auth errors), tell them to re-run `brightspace-auth` rather than guessing.
  '';
in
{
  ${commandName} = {
    inherit
      commandName
      description
      argumentHint
      prompt
      ;
  };
}
