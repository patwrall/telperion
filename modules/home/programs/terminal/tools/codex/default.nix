{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.terminal.tools.codex;
  mcpModuleEnabled = config.telperion.programs.terminal.tools.mcp.enable or false;
  aiTools = import (lib.getFile "modules/common/ai-tools") { inherit lib; };
in
{
  options.telperion.programs.terminal.tools.codex = {
    enable = mkEnableOption "Codex CLI configuration";
  };

  config = mkIf cfg.enable {
    programs.codex = {
      enable = true;

      enableMcpIntegration = mkIf mcpModuleEnabled true;

      context = aiTools.base;
      skills = aiTools.codex.skillsDir;
    };
  };
}
