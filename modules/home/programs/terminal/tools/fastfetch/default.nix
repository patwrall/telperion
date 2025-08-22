{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.terminal.tools.fastfetch;
in
{
  options.telperion.programs.terminal.tools.fastfetch = {
    enable = mkEnableOption "Fastfetch";
  };


  config = mkIf cfg.enable {
    programs.fastfetch = {
      enable = true;

      settings = lib.importJSON ./config.jsonc;
    };
  };
}
