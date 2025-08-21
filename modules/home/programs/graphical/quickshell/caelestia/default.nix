{ config
, inputs
, lib
, system
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  inherit (lib.telperion) enabled;

  cfg = config.telperion.programs.graphical.quickshell.caelestia;

  caelestia-shell = inputs.caelestia-shell.packages.${system}.default.override {
    withCli = true;
  };

  caelestia-cli = inputs.caelestia-cli.packages.${system}.caelestia-cli;
in
{
  options.telperion.programs.graphical.quickshell.caelestia = {
    enable = mkEnableOption "Caelestia quickshell configuration";
  };

  config = mkIf cfg.enable {
    home.packages = [
      caelestia-shell
      caelestia-cli
    ];

    telperion.programs.graphical.gtk = enabled;
  };
}
