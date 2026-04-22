{ config
, lib
, ...
}:
let
  cfg = config.telperion.programs.terminal.tools.mcp;
in
{
  options.telperion.programs.terminal.tools.mcp = {
    enable = lib.mkEnableOption "MCP (Model Context Protocol) servers";
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
        args = [
          config.home.homeDirectory
          "${config.home.homeDirectory}/Documents"
          "${config.home.homeDirectory}/telperion"
          "/nix/store"
        ];
      };

      git.enable = true;
      sequential-thinking.enable = true;
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
  };
}
