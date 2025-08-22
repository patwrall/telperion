{ config
, lib
, pkgs
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
      package = pkgs.fastfetchMinimal;

      settings = lib.importJSON ./config.jsonc;
    };
  };
}
