{ config
, lib
, pkgs
, osConfig ? { }
, ...
}:
let
  inherit (lib) mkIf getExe;

  cfg = config.telperion.programs.graphical.wms.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        exec-once =
          let
            mkStartCommand =
              cmd: if (osConfig.programs.uwsm.enable or false) then "uwsm app -- ${cmd}" else cmd;
          in
          (map mkStartCommand [
            "${getExe pkgs.discordo}"
            "${getExe config.programs.spotify-player.package}"
            "${getExe  config.programs.btop.package}"
          ])
          ++ lib.optionals (osConfig.programs.uwsm.enable or false) [ "uwsm finalize" ];
      };
    };
  };
}
