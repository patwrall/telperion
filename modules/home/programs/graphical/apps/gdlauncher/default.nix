{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.gdlauncher;

in
{
  options.telperion.programs.graphical.apps.gdlauncher = {
    enable = mkEnableOption "gdlauncher";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      gdlauncher-carbon
    ];
  };
}
