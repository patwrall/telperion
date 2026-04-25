{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.terminal.tools.claude-code;
  mcpModuleEnabled = config.telperion.programs.terminal.tools.mcp.enable or false;
  aiTools = import (lib.getFile "modules/common/ai-tools") { inherit lib; };

  claudeIcon = ./assets/claude.ico;

  # Register the discord plugin under its real marketplace ID so
  # `--channels plugin:discord@claude-plugins-official` resolves. Sideloading
  # via `--plugin-dir` would tag it `@inline` and break channel routing.
  discordPlugin = pkgs.telperion.claude-discord-plugin;
  installedPlugins = (pkgs.formats.json { }).generate "installed_plugins.json" {
    version = 2;
    plugins = {
      "discord@claude-plugins-official" = [
        {
          scope = "user";
          installPath = "${discordPlugin}";
          version = discordPlugin.version or "0.0.4";
          installedAt = "1970-01-01T00:00:00Z";
          lastUpdated = "1970-01-01T00:00:00Z";
        }
      ];
    };
  };
in
{
  imports = [
    ./permissions.nix
  ];

  options.telperion.programs.terminal.tools.claude-code = {
    enable = mkEnableOption "Claude Code configuration";
  };

  config = mkIf cfg.enable {
    # Install Claude icon for notifications
    xdg.dataFile."icons/claude.ico".source = claudeIcon;

    # Put the FHS-wrapped Brightspace auth CLI on PATH so re-auth is one command.
    home.packages = [ pkgs.telperion.brightspace-auth ];

    home.file.".claude/plugins/installed_plugins.json".source = installedPlugins;

    programs.claude-code = {
      enable = true;

      enableMcpIntegration = mkIf mcpModuleEnabled true;

      mcpServers = {
        brightspace-mcp-server = {
          type = "stdio";
          command = lib.getExe pkgs.telperion.brightspace-mcp-server;
        };
      };

      settings = {
        theme = "dark";

        # Mark the discord plugin as enabled so its MCP server, skills, and
        # commands are loaded. The presence of the key (any non-undefined
        # value) is what Claude Code's `Hu()` checks against.
        enabledPlugins."discord@claude-plugins-official" = true;

        hooks = lib.importDir ./hooks { inherit pkgs config lib; };

        # Let default do its job
        # model = "claude-sonnet-4-6";
        verbose = true;
        includeCoAuthoredBy = false;
        gitAttribution = false;
        attribution = {
          commit = "";
          pr = "";
        };

        statusLine = {
          type = "command";
          command = "input=$(cat); echo \"[$(echo \"$input\" | jq -r '.model.display_name')] 📁 $(basename \"$(echo \"$input\" | jq -r '.workspace.current_dir')\")\"";
          padding = 0;
        };

        env = {
          USE_BUILTIN_RIPGREP = "0";
        }
        // lib.optionalAttrs mcpModuleEnabled {
          ENABLE_TOOL_SEARCH = "auto:5";
        };
      };

      inherit (aiTools.claudeCode) agents commands;
      skills = aiTools.claudeCode.skillsDir;
      context = aiTools.base;
    };
  };
}
