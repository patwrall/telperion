{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) getExe mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.quickshell.caelestia;

  mkStartCommand = cmd: "app2unit -- ${cmd}";
in
{
  options.telperion.programs.graphical.quickshell.caelestia = {
    enable = mkEnableOption "Caelestia quickshell configuration";
  };

  config = mkIf cfg.enable {
    programs.caelestia = {
      enable = true;
      cli = {
        enable = true;
        settings = {
          theme = {
            enableSpicetify = true;
          };
          toggles = {
            communication = {
              vesktop = {
                enable = true;
                match = [
                  { class = "vesktop"; }
                ];
                command = [
                  "app2unit"
                  "--"
                  "${getExe pkgs.vesktop}"
                ];
              };
            };
            music = {
              spotify = {
                enable = true;
                match = [
                  { class = "Spotify"; }
                  { initialTitle = "Spotify"; }
                  { initialTitle = "Spotify Free"; }
                ];
                command = [ "${mkStartCommand "${getExe config.programs.spicetify.spicedSpotify}"}" ];
              };
            };
            sysmon = {
              btop = {
                enable = true;
                match = [
                  {
                    class = "btop";
                    title = "btop";
                    workspace = {
                      name = "special:sysmon";
                    };
                  }
                ];
                command = [
                  "foot"
                  "-a"
                  "btop"
                  "-T"
                  "btop"
                  "fish"
                  "-C"
                  "${mkStartCommand "${getExe config.programs.btop.package}"}"
                ];
              };
            };
          };
        };
      };
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
