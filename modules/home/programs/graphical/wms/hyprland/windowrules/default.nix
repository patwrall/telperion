{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.graphical.wms.hyprland;
in
{
  imports = [
    ./floating.nix
    ./layers.nix
    ./workspace.nix
  ];

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        windowrule = [
          # fix xwayland apps
          "rounding 10, match:xwayland true, match:title win[0-9]+"
          "no_shadow on, match:xwayland true, match:title win[0-9]+"
          "no_dim on, match:xwayland true, match:title win[0-9]+"

          "center 1, match:class ^(.*jetbrains.*)$, match:title ^(Confirm Exit|Open Project|win424|win201|splash)$"
          "size 640 400, match:class ^(.*jetbrains.*)$, match:title ^(splash)$"

          # xwaylandvideobridge
          "opacity 0.0 override 0.0 override, match:class ^(xwaylandvideobridge)$"
          "no_anim on, match:class ^(xwaylandvideobridge)$"
          "no_initial_focus on, match:class ^(xwaylandvideobridge)$"
          "max_size 1 1, match:class ^(xwaylandvideobridge)$"
          "no_blur on, match:class ^(xwaylandvideobridge)$"

          # fix drag and drop not working for scene builder
          "no_focus on, match:title java"

          # Steam
          # (title: was effectively “match anything”, so we just drop it or use .*)
          "rounding 10, match:class steam"
          "immediate on, match:class steam_app_[0-9]+"
          "idle_inhibit always, match:class steam_app_[0-9]+"

          # Picture in picture
          "move 100%-w-2% 100%-w-3%, match:title Picture(-| )in(-| )[Pp]icture"
          "keep_aspect_ratio on, match:title Picture(-| )in(-| )[Pp]icture"
          "float on, match:title Picture(-| )in(-| )[Pp]icture"
          "pin on, match:title Picture(-| )in(-| )[Pp]icture"

          # Dim non-fullscreen windows based on your opacity var
          "opacity $windowOpacity override, match:fullscreen false"

          "opaque on, match:class foot|equibop|org\\.quickshell|imv|swappy"

          # center floating wayland-native windows
          "center 1, match:float true, match:xwayland false"
        ];
      };
    };
  };
}
