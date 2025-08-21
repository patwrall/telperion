{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.graphical.wms.hyprland;
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        layerrule = [
          # General
          "animation fade, hyprpicker"
          "animation fade, logout_dialog"
          "animation fade, selection"
          "animation fade, wayfreeze"

          # Fuzzel
          "animation popin 80%, launcher"
          "blur, launcher"

          # Caelestia Shell
          "noanim, caelestia-(border-exclusion|area-picker)"
          "animation fade, caelestia-(drawers|background)"
          "blur, caelestia-drawers"
          "ignorealpha 0.57, caelestia-drawers"
        ];
      };
    };
  };
}
