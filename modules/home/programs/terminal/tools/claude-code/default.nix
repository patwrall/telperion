{ config
, lib
, pkgs
, ...
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
  figmaPlugin = pkgs.telperion.claude-figma-plugin;

  # pstack belongs to no marketplace, so its package builds a one-entry
  # marketplace with the plugin one level down. See its package.nix.
  pstackMarketplace = pkgs.telperion.claude-pstack-plugin;

  # `claude plugin install` cannot run here: it rewrites ~/.claude/settings.json,
  # which HM links read-only into the store. Plugins are declared instead.
  installedPlugin = version: installPath: [
    {
      scope = "user";
      inherit installPath version;
      installedAt = "1970-01-01T00:00:00Z";
      lastUpdated = "1970-01-01T00:00:00Z";
    }
  ];

  installedPlugins = (pkgs.formats.json { }).generate "installed_plugins.json" {
    version = 2;
    plugins = {
      "discord@claude-plugins-official" = installedPlugin discordPlugin.version "${discordPlugin}";
      "figma@claude-plugins-official" = installedPlugin figmaPlugin.version "${figmaPlugin}";
      "pstack@backnotprop" = installedPlugin pstackMarketplace.version "${pstackMarketplace}/pstack";
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
    # sox provides `rec`, the audio-capture backend voice dictation shells out to.
    home = {
      packages = [
        pkgs.telperion.brightspace-auth
        pkgs.sox
      ];

      file.".claude/plugins/installed_plugins.json".source = installedPlugins;

      # known_marketplaces.json stays Claude Code's: it refreshes the
      # claude-plugins-official checkout and rewrites lastUpdated, which a
      # read-only store symlink would break. Re-apply just our entry instead, the
      # same way codexWritableConfig keeps Codex's config.toml writable.
      activation.claudePstackMarketplace = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        MARKETPLACES="$HOME/.claude/plugins/known_marketplaces.json"

        mkdir -p "$(dirname "$MARKETPLACES")"
        if [ ! -s "$MARKETPLACES" ]; then
          echo '{}' > "$MARKETPLACES"
        fi

        # Full store path: activation runs with a minimal PATH that has no jq.
        ${pkgs.jq}/bin/jq --arg path "${pstackMarketplace}" '
          .backnotprop = {
            source: { source: "directory", path: $path },
            installLocation: $path,
            lastUpdated: "1970-01-01T00:00:00Z",
          }
        ' "$MARKETPLACES" > "$MARKETPLACES.hm-new"

        mv "$MARKETPLACES.hm-new" "$MARKETPLACES"
      '';
    };

    telperion.programs.terminal.tools.claude-code.permissionProfile = "autonomous";

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
        theme = "dark-daltonism";

        voice = {
          enabled = true;
          mode = "hold";
          autoSubmit = true;
        };

        # Mark the discord plugin as enabled so its MCP server, skills, and
        # commands are loaded. The presence of the key (any non-undefined
        # value) is what Claude Code's `Hu()` checks against.
        enabledPlugins = {
          "discord@claude-plugins-official" = true;
          "figma@claude-plugins-official" = true;
          "pstack@backnotprop" = true;
        };

        hooks = lib.importDir ./hooks { inherit pkgs config lib; };

        # `/model` can't persist a choice: this file is a read-only store link.
        model = "claude-opus-5-5[1m]";
        verbose = true;
        includeCoAuthoredBy = false;
        gitAttribution = false;
        remoteControlAtStartup = false;
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
