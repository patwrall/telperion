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
            mkStartCommand = cmd: "app2unit -- ${cmd}";
          in
          (map mkStartCommand [
            "${getExe pkgs.vesktop}"
            "${getExe config.programs.spicetify.spicedSpotify}"
            "${getExe config.programs.btop.package}"
          ])
          ++ lib.optionals (osConfig.programs.uwsm.enable or false) [ "uwsm finalize" ];
      };
    };
  };
}
