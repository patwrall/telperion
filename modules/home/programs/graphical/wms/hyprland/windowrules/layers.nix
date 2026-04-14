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

          # Ambxst Shell
          "no_anim on, match:namespace selection"
          "blur on, match:namespace ambxst"
          "no_anim on, match:namespace ambxst"
          "ignore_alpha 0.5, match:namespace ambxst"
          "blur on, match:namespace overview"
          "no_anim on, match:namespace overview"
          "blur on, match:namespace presets"
          "no_anim on, match:namespace presets"
        ];
      };
    };
  };
}
