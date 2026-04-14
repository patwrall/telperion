{
  config,
  lib,
  # pkgs,
  inputs,
  system,
  ...
}:
let
  inherit (lib)
    getExe
    ;

  cfg = config.telperion.programs.terminal.tools.mcp;
  mcpPkgs = inputs.mcp-servers-nix.packages.${system};
in
{
  options.telperion.programs.terminal.tools.mcp = {
    enable = lib.mkEnableOption "MCP (Model Context Protocol) servers";
  };

  config = lib.mkIf cfg.enable {
    programs.mcp = {
      # MCP documentation
      # See: https://modelcontextprotocol.io/
      enable = true;
      servers = {
        fetch = {
          command = getExe mcpPkgs.mcp-server-fetch;
        };

        filesystem = {
          command = getExe mcpPkgs.mcp-server-filesystem;
          args = lib.mkDefault [
            config.home.homeDirectory
            "${config.home.homeDirectory}/Documents"
            "${config.home.homeDirectory}/telperion"
            "/nix/store"
          ];
        };

        sequential-thinking = {
          command = getExe mcpPkgs.mcp-server-sequential-thinking;
        };

        git = {
          command = getExe mcpPkgs.mcp-server-git;
        };

        # FIXME: broken nixpkgs
        # nixos = {
        #   command = getExe pkgs.mcp-nixos;
        # };
      };
    };
  };
}
