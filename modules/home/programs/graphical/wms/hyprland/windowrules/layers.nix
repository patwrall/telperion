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
          "animation fade, match:namespace hyprpicker"
          "animation fade, match:namespace logout_dialog"
          "animation fade, match:namespace selection"
          "animation fade, match:namespace wayfreeze"

          # Fuzzel
          "animation popin 80%, match:namespace launcher"
          "blur on, match:namespace launcher"

          # Caelestia Shell
          "no_anim on, match:namespace caelestia-(border-exclusion|area-picker)"
          "animation fade, match:namespace caelestia-(drawers|background)"
          "blur on, match:namespace caelestia-drawers"
          "ignore_alpha 0.57, match:namespace caelestia-drawers"
        ];
      };
    };
  };
}
