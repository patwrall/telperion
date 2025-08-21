{ config
, lib
, ...
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
          "rounding 10, xwayland:1, title:win[0-9]+"
          "noshadow, xwayland:1, title:win[0-9]+"
          "nodim, xwayland:1, title:win[0-9]+"
          "center, class:^(.*jetbrains.*)$, title:^(Confirm Exit|Open Project|win424|win201|splash)$"
          "size 640 400, class:^(.*jetbrains.*)$, title:^(splash)$"

          # xwaylandvideobridge
          "opacity 0.0 override 0.0 override,class:^(xwaylandvideobridge)$"
          "noanim,class:^(xwaylandvideobridge)$"
          "noinitialfocus,class:^(xwaylandvideobridge)$"
          "maxsize 1 1,class:^(xwaylandvideobridge)$"
          "noblur,class:^(xwaylandvideobridge)$"

          # Steam
          "rounding 10, title:, class:steam"
          "immediate, class:steam_app_[0-9]+"
          "idleinhibit always, class:steam_app_[0-9]+"

          # Picture in picture
          "move 100%-w-2% 100%-w-3%, title:Picture(-| )in(-| )[Pp]icture"
          "keepaspectratio, title:Picture(-| )in(-| )[Pp]icture"
          "float, title:Picture(-| )in(-| )[Pp]icture"
          "pin, title:Picture(-| )in(-| )[Pp]icture"

          "opacity $windowOpacity override, fullscreen:0"
          "opaque, class:foot|equibop|org\\.quickshell|imv|swappy"
          "center 1, floating:1, xwayland:0"
        ];
      };
    };
  };
}
