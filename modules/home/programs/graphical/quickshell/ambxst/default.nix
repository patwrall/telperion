{ config
, lib
, ...
}:
let
  cfg = config.telperion.programs.graphical.quickshell.ambxst;
in
{
  options.telperion.programs.graphical.quickshell.ambxst = {
    enable = lib.mkEnableOption "Ambxst shell integration";
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland.settings.exec-once = [ "ambxst" ];
  };
}
