{ config
, inputs
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption getExe;
  inherit (inputs) caelestia-shell;

  cfg = config.telperion.programs.graphical.quickshell.caelestia;
in
{
  options.telperion.programs.graphical.quickshell.caelestia = {
    enable = mkEnableOption "Caelestia quickshell configuration";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      caelestia-shell
    ];
  };
}
