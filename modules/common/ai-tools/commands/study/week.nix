let
  commandName = "week";
  description = "Show Brightspace assignments due in the next 7 days grouped by day";
  argumentHint = "[days]";
  prompt = ''
    Show a 7-day lookahead of Brightspace deadlines, grouped by day of the week.

    If `$1` is a number, use that as the horizon instead of 7.

    **Steps:**

    1. Call `get_upcoming_due_dates` covering the horizon. Single batched call.

    2. Group items by day (local time). Within a day, order by due time ascending.

    3. Render:

       ```
       ## This week

       ### Tuesday (2026-04-23)
       - 11:59pm — CS 23200 — HW5 (50 pts)
       - 11:59pm — CS 26000 — Lab 7 (20 pts)

       ### Wednesday (2026-04-24)
       (nothing due)
       ```

       Include day-of-week + ISO date. Skip days entirely if nothing's due and there's adjacent activity — but include an empty "(nothing due)" line if the adjacent days have items, so the student sees the breathing room.

    4. Below the list, a one-line summary: "N items due this week, totaling M points."

    **Also optionally run prioritization.** If the user asks for "what to do first" in the same turn, or if the horizon is ≤ 3 days (implying urgency), automatically also run the prioritize skill's script on this data and append a "Top 3 to work on" block.

    **Guardrails:**
    - Don't editorialize on workload ("looks light/heavy"). Facts only unless asked.
    - Don't include items already submitted.
    - If MCP session expired, stop and tell the user to re-run `brightspace-auth`.
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
