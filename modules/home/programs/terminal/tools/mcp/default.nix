{ config
, lib
, pkgs
, inputs
, ...
}:
let
  cfg = config.telperion.programs.terminal.tools.mcp;

  # Workaround for a broken mcp-servers-nix build for the "filesystem" and
  # "sequential-thinking" reference servers. Two independent upstream bugs:
  # nixpkgs' `typescript` attr now defaults to the TypeScript 7 (Go-based
  # preview) compiler, which fails to resolve @types/node for these
  # packages' TS5 sources ("Cannot find name 'fs'" etc); and each workspace's
  # "prepare": "npm run build" script races npm's own dependency hoisting
  # during `npm ci --ignore-scripts` in Nix's npmConfigHook, occasionally
  # building a sibling workspace before its devDependencies are linked.
  # Remove this once mcp-servers-nix pins typescript_5 and/or upstream drops
  # the redundant "prepare" scripts from the servers monorepo.
  fixMcpTsServer = service: workspace:
    (pkgs.callPackage
      (import "${inputs.mcp-servers-nix}/pkgs/reference/generic-ts.nix" {
        inherit service workspace;
      })
      { typescript = pkgs.typescript_5; }).overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        sed -i '/"prepare": "npm run build",/d' src/*/package.json
      '';
    });
in
{
  options.telperion.programs.terminal.tools.mcp = {
    enable = lib.mkEnableOption "MCP (Model Context Protocol) servers";

    canvas = {
      enable = lib.mkEnableOption "canvas-mcp server";

      apiUrl = lib.mkOption {
        type = lib.types.str;
        description = "Canvas institution URL (e.g. https://canvas.purdue.edu).";
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "%h/.config/canvas-mcp/token";
        description = "Path to a file containing the Canvas API token (chmod 600). Use %h for home dir.";
      };
    };

    discord = {
      enable = lib.mkEnableOption "discord-mcp server";

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "%h/.config/discord-mcp/token";
        description = "Path to a file containing the Discord bot token (chmod 600). Use %h for home dir.";
      };

      guildId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional default Discord guild ID passed to the server.";
      };
    };

    garmin = {
      enable = lib.mkEnableOption "garmin-mcp server";

      isCn = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use Garmin Connect China (garmin.cn) instead of the international service.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Centralized registry consumed by programs.claude-code via
    # `enableMcpIntegration = true` (wired in the claude-code module).
    # See: https://github.com/natsukium/mcp-servers-nix
    programs.mcp.enable = true;

    mcp-servers.programs = {
      fetch.enable = true;

      filesystem = {
        enable = true;
        package = fixMcpTsServer "filesystem" "filesystem";
        args = [
          config.home.homeDirectory
          "${config.home.homeDirectory}/Documents"
          "${config.home.homeDirectory}/telperion"
          "/nix/store"
        ];
      };

      git.enable = true;
      sequential-thinking = {
        enable = true;
        package = fixMcpTsServer "sequential-thinking" "sequentialthinking";
      };
      context7.enable = true;
      playwright.enable = true;

      # Token resolved at server spawn via 1Password CLI — requires an item
      # "GitHub MCP" (field "token") in the "Private" vault. See README for
      # how to provision it.
      github = {
        enable = true;
        passwordCommand = {
          GITHUB_PERSONAL_ACCESS_TOKEN = [ "op" "read" "op://Private/GitHub MCP/token" ];
        };
      };
    };

    programs.claude-code.mcpServers = lib.mkMerge [
      (lib.mkIf cfg.canvas.enable {
        canvas-mcp = {
          type = "stdio";
          command = lib.getExe (pkgs.writeShellScriptBin "canvas-mcp-server-wrapped" ''
            token_file="${builtins.replaceStrings ["%h"] ["$HOME"] cfg.canvas.tokenFile}"
            if [ ! -f "$token_file" ]; then
              echo "canvas-mcp: token file not found: $token_file" >&2
              exit 1
            fi
            export CANVAS_API_TOKEN=$(< "$token_file")
            export CANVAS_API_URL=${lib.escapeShellArg cfg.canvas.apiUrl}
            exec ${lib.getExe pkgs.telperion.canvas-mcp-server} "$@"
          '');
        };
      })
      (lib.mkIf cfg.discord.enable {
        discord-mcp = {
          type = "stdio";
          command = lib.getExe (pkgs.writeShellScriptBin "discord-mcp-server-wrapped" ''
            token_file="${builtins.replaceStrings ["%h"] ["$HOME"] cfg.discord.tokenFile}"
            if [ ! -f "$token_file" ]; then
              echo "discord-mcp: token file not found: $token_file" >&2
              exit 1
            fi
            export DISCORD_TOKEN=$(< "$token_file")
            ${lib.optionalString (cfg.discord.guildId != null) "export DISCORD_GUILD_ID=${lib.escapeShellArg cfg.discord.guildId}"}
            export JAVA_TOOL_OPTIONS="-Dlogging.file.path=${config.xdg.stateHome}/discord-mcp"
            exec ${lib.getExe pkgs.telperion.discord-mcp-server} "$@"
          '');
        };
      })
      (lib.mkIf cfg.garmin.enable {
        garmin-mcp = {
          type = "stdio";
          command = lib.getExe (pkgs.writeShellScriptBin "garmin-mcp-server-wrapped" ''
            ${lib.optionalString cfg.garmin.isCn "export GARMIN_IS_CN=true"}
            exec ${lib.getExe pkgs.telperion.garmin-mcp-server} "$@"
          '');
        };
      })
    ];

    # Puts `garmin-mcp-auth` on PATH — run it once interactively to save
    # OAuth tokens to ~/.garminconnect before the MCP server can fetch data.
    home.packages = lib.mkIf cfg.garmin.enable [ pkgs.telperion.garmin-mcp-server ];
  };
}
