{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.quickshell.caelestia;

in
{
  options.telperion.programs.graphical.quickshell.caelestia = {
    enable = mkEnableOption "Caelestia quickshell configuration";
  };

  config = mkIf cfg.enable {
    programs.caelestia = {
      enable = true;
      cli.enable = true;
      settings = {
        background = {
          visualiser = {
            enabled = false;
          };
        };
        bar = {
          workspaces = {
            label = "";
          };
        };
        services = {
          useTwelveHourClock = false;
        };
      };
    };
  };
}
