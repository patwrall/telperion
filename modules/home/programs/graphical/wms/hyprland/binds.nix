{ config
, lib
, pkgs
, osConfig ? { }
, ...
}:
let
  inherit (lib) mkIf getExe;

  cfg = config.telperion.programs.graphical.wms.hyprland;

  # Helper functions
  mkStartCommand =
    cmd:
    if (osConfig.programs.uwsm.enable or false) then "uwsm app -- ${cmd}" else "run-as-service ${cmd}";
  mkExecBind =
    bind:
    let
      parts = builtins.split "exec, " bind;
      pre = builtins.head parts;
      cmd = builtins.elemAt parts 2;
    in
    "${pre}exec, ${mkStartCommand cmd}";
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        bind =
          let
          in
          { };

        bindi = [
          "$mainMod, Super_L, global, caelestia:launcher"
        ];

        bindl = [ ];

        bindm = [ ];
      };
    };
  };
}
