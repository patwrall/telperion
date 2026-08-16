_: {
  PreToolUse = [
    # Pattern-based security validation for Bash commands
    # Only includes patterns that permissions.nix can't express (regex-based detection)
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          timeout = 5;
          command = /* Bash */ ''
            input=$(cat)
            cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

            # Dangerous patterns that require regex detection
            dangerous_patterns=(
              # Arbitrary code execution from network (pipe to shell)
              'curl.*\|.*sh'
              'curl.*\|.*bash'
              'wget.*\|.*sh'
              'wget.*\|.*bash'
              'eval.*\$\(curl'
              'eval.*\$\(wget'
              # Fork bomb
              ':\(\)\{.*:\|:.*\};:'
            )

            for pattern in "''${dangerous_patterns[@]}"; do
              if echo "$cmd" | grep -qE "$pattern"; then
                echo '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"Dangerous command pattern detected"}}'
                exit 2
              fi
            done

            exit 0
          '';
        }
      ];
    }
    # Path traversal prevention
    {
      matcher = "Write|Edit|MultiEdit|Read";
      hooks = [
        {
          type = "command";
          timeout = 5;
          command = ''
            input=$(cat)

            # Check for path traversal attempts.
            # Only the path-shaped fields. Scanning every tool_input value also
            # scanned `content` and `new_string`, so any source file holding a
            # relative parent import was rejected as an attack.
            if echo "$input" | jq -r '.tool_input | (.file_path // empty), (.notebook_path // empty)' 2>/dev/null | grep -qE '\.\./' ; then
              echo '{"hookSpecificOutput":{"permissionDecision":"deny","permissionDecisionReason":"Path traversal attempt detected"}}'
              exit 2
            fi

            exit 0
          '';
        }
      ];
    }
  ];
}
