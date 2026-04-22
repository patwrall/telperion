let
  commandName = "grades";
  description = "Show a formatted grade summary across Brightspace courses";
  prompt = ''
    Pull a grade snapshot from Brightspace and format it for quick scanning.

    **Steps:**

    1. Call `get_my_courses` + `get_my_grades` via the brightspace-mcp-server MCP. Prefer a single batched call if available.

    2. For each course, assemble:
       - Course name (short form: e.g. `CS 23200`)
       - Current numeric grade (if known)
       - Current letter grade (if known)
       - The 3 most recent graded items in that course with points earned / possible

    3. Render as grouped markdown:

       ```
       ## CS 23200 Intro to C and UNIX — 87.3% (B+)
       | Item          | Earned / Possible | Graded |
       |---------------|-------------------|--------|
       | HW4           | 45 / 50           | 3d ago |
       ```

       One section per course. No section if the course has no grade yet — say so explicitly ("No graded items in <course>").

    4. At the bottom, a one-liner per course showing distance to next letter
       grade boundary (e.g. "CS 23200: 2.7pt from A-"). Assume standard scale
       (A=93, A-=90, B+=87, B=83, B-=80, C+=77, C=73, ...) unless the user's
       config says otherwise. Flag the assumption in a footer.

    **Guardrails:**
    - If a numeric grade is missing, show `—`, not a guess.
    - Don't order courses by grade (high-to-low or low-to-high). Order by course code so the output is stable across runs.
    - If the MCP session has expired, stop and tell the user to re-run `brightspace-auth`.
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
