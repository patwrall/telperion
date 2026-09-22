{ config
, lib
, ...
}:
let
  inherit (lib) mkOption types mkIf;

  cfg = config.telperion.programs.terminal.tools.claude-code;

  # Base safe operations - always allowed regardless of profile
  baseAllow = [
    # Core Claude Code tools
    "Glob(*)"
    "Grep(*)"
    "LS(*)"
    "Read(*)"
    "Search(*)"
    "Task(*)"
    "TodoWrite(*)"

    # Safe read-only git commands
    "Bash(git status)"
    "Bash(git log:*)"
    "Bash(git diff:*)"
    "Bash(git show:*)"
    "Bash(git branch:*)"
    "Bash(git remote:*)"

    # Safe file system operations
    "Bash(ls:*)"
    "Bash(find:*)"
    "Bash(cat:*)"
    "Bash(head:*)"
    "Bash(tail:*)"

    # Safe nix read operations
    "Bash(nix eval:*)"
    "Bash(nix flake show:*)"
    "Bash(nix flake metadata:*)"

    # MCP tools - read only
    "mcp__github__search_repositories"
    "mcp__github__get_file_contents"
    "mcp__sequential-thinking__sequentialthinking"

    # Brightspace MCP - all tools are read-only (fetch grades, assignments, etc.)
    # The HM claude-code plugin namespaces MCP tools as
    # `mcp__plugin_claude-code-home-manager_<server>__<tool>`.
    "mcp__plugin_claude-code-home-manager_brightspace-mcp-server"

    # Filesystem MCP - read operations
    "mcp__filesystem__read_file"
    "mcp__filesystem__read_text_file"
    "mcp__filesystem__read_media_file"
    "mcp__filesystem__read_multiple_files"
    "mcp__filesystem__list_directory"
    "mcp__filesystem__list_directory_with_sizes"
    "mcp__filesystem__directory_tree"
    "mcp__filesystem__search_files"
    "mcp__filesystem__get_file_info"
    "mcp__filesystem__list_allowed_directories"

    # Trusted web domains
    "WebFetch(domain:github.com)"
    "WebFetch(domain:wiki.hyprland.org)"
    "WebFetch(domain:wiki.hypr.land)"
    "WebFetch(domain:raw.githubusercontent.com)"
    "WebFetch(domain:snowfall.org)"
    "WebFetch(domain:devenv.sh)"
  ];

  # Standard profile additions - balanced permissions
  standardAllow = baseAllow ++ [
    # Git staging
    "Bash(git add:*)"

    # All nix commands
    "Bash(nix:*)"

    # Directory creation
    "Bash(mkdir:*)"
    "Bash(chmod:*)"

    # Search tools
    "Bash(rg:*)"
    "Bash(grep:*)"

    # System info
    "Bash(systemctl list-units:*)"
    "Bash(systemctl list-timers:*)"
    "Bash(systemctl status:*)"
    "Bash(journalctl:*)"
    "Bash(dmesg:*)"
    "Bash(env)"
    "Bash(claude --version)"
    "Bash(nh search:*)"

    # Audio system (read-only)
    "Bash(pactl list:*)"
    "Bash(pw-top)"

    # Hyprland
    "Bash(hyprctl dispatch:*)"

    # Sway
    "Bash(swaymsg:*)"
    "Bash(swaync-client:*)"
    "Bash(uwsm check:*)"

    # Debugging
    "Bash(coredumpctl list:*)"

    # Work MCP
    "mcp__mulesoft-analyzer"

    # Additional home directory reads
    "Read(${config.home.homeDirectory}/Documents/github/home-manager/**)"
    "Read(${config.home.homeDirectory}/.config/sway/**)"
  ];

  # Autonomous profile additions - full autonomy for trusted workflows.
  #
  # Bare "Bash" allows every Bash command. Enumerating them was losing fights
  # it shouldn't: research subagents stalled waiting on a confirmation for
  # `curl`, and `Bash(systemctl:*)` in autonomousAsk shadowed the read-only
  # `systemctl status` entries below (deny > ask > allow).
  #
  # The floor is denyList plus the PreToolUse hook, both of which outrank
  # allow: rm -rf /, dd, mkfs, curl|sh pipe-to-shell, fork bombs.
  autonomousAllow = standardAllow ++ [
    "Bash"
  ];

  # Operations requiring confirmation in non-autonomous mode
  standardAsk = [
    # Potentially destructive git commands
    "Bash(git checkout:*)"
    "Bash(git commit:*)"
    "Bash(git merge:*)"
    "Bash(git pull:*)"
    "Bash(git push:*)"
    "Bash(git rebase:*)"
    "Bash(git reset:*)"
    "Bash(git restore:*)"
    "Bash(git stash:*)"
    "Bash(git switch:*)"

    # File deletion and modification
    "Bash(cp:*)"
    "Bash(mv:*)"
    "Bash(rm:*)"

    # System control operations
    "Bash(systemctl disable:*)"
    "Bash(systemctl enable:*)"
    "Bash(systemctl mask:*)"
    "Bash(systemctl reload:*)"
    "Bash(systemctl restart:*)"
    "Bash(systemctl start:*)"
    "Bash(systemctl stop:*)"
    "Bash(systemctl unmask:*)"

    # Network operations
    "Bash(curl:*)"
    "Bash(ping:*)"
    "Bash(rsync:*)"
    "Bash(scp:*)"
    "Bash(ssh:*)"
    "Bash(wget:*)"

    # Package management
    "Bash(nixos-rebuild:*)"
    "Bash(sudo:*)"

    # Process management
    "Bash(kill:*)"
    "Bash(killall:*)"
    "Bash(pkill:*)"
  ];

  # Autonomous mode allows every Bash command (see autonomousAllow), so this
  # list is the whole guardrail. It holds only operations that leave this
  # machine, change system state, or rewrite published history - the ones
  # worth waking someone up for. Everything a research subagent does
  # (curl, wget, gh, nix, ps, read-only systemctl) runs unattended.
  autonomousAsk = [
    # Publishing / history rewrites
    "Bash(git push:*)"
    "Bash(git merge:*)"
    "Bash(git rebase:*)"

    # Privilege escalation and system rebuilds
    "Bash(sudo:*)"
    "Bash(nixos-rebuild:*)"

    # Mutating systemctl verbs only - `systemctl status`, `cat` and the
    # `list-*` subcommands stay unprompted. A bare `systemctl:*` here used to
    # shadow the read-only entries in standardAllow, since ask outranks allow.
    "Bash(systemctl start:*)"
    "Bash(systemctl stop:*)"
    "Bash(systemctl restart:*)"
    "Bash(systemctl reload:*)"
    "Bash(systemctl enable:*)"
    "Bash(systemctl disable:*)"
    "Bash(systemctl mask:*)"
    "Bash(systemctl unmask:*)"

    # Anything that reaches another host
    "Bash(ssh:*)"
    "Bash(scp:*)"
    "Bash(rsync:*)"

    # Killing processes outside this session
    "Bash(kill:*)"
    "Bash(killall:*)"
    "Bash(pkill:*)"
  ];

  # Never allowed - dangerous operations
  denyList = [
    "Bash(rm -rf /*)"
    "Bash(rm -rf /)"
    "Bash(dd:*)"
    "Bash(mkfs:*)"
  ];
in
{
  options.telperion.programs.terminal.tools.claude-code.permissionProfile = mkOption {
    type = types.enum [
      "conservative"
      "standard"
      "autonomous"
    ];
    default = "standard";
    description = ''
      Permission profile for Claude Code operations:
      - conservative: Minimal permissions, most operations require confirmation
      - standard: Balanced permissions for normal development workflows
      - autonomous: Maximum autonomy for trusted environments
    '';
  };

  config = mkIf cfg.enable {
    programs.claude-code.settings.permissions = {
      allow =
        if cfg.permissionProfile == "autonomous" then
          autonomousAllow
        else if cfg.permissionProfile == "standard" then
          standardAllow
        else
          baseAllow;

      ask =
        if cfg.permissionProfile == "autonomous" then
          autonomousAsk
        else if cfg.permissionProfile == "standard" then
          standardAsk
        else
          standardAsk ++ standardAllow; # Conservative: ask for everything standard allows

      deny = denyList;

      defaultMode = if cfg.permissionProfile == "autonomous" then "acceptEdits" else "default";
    };
  };
}
