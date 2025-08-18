{ config
, inputs
, lib
, system
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.quickshell.caelestia;

  caelestia-shell = inputs.caelestia-shell.packages.${system}.default.override {
    withCli = true;
  };
in
{
  options.telperion.programs.graphical.quickshell.caelestia = {
    enable = mkEnableOption "Caelestia quickshell configuration";
  };

  config = mkIf cfg.enable {
    home.packages = [
      caelestia-shell
    ];
  };
}
