{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.rnote;

in
{
  options.telperion.programs.graphical.apps.rnote = {
    enable = mkEnableOption "rnote";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      rnote
    ];
  };
}
