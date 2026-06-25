{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.anki;

in
{
  options.telperion.programs.graphical.apps.anki = {
    enable = mkEnableOption "anki";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      anki
    ];
  };
}
