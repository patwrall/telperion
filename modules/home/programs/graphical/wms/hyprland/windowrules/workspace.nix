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
        windowrule = [
          "workspace special:sysmon, match:class btop"
          "workspace 9, match:class Spotify|feishin|Supersonic|spotify_player"
          "workspace 9, match:initial_title Spotify( Free)?"
          "workspace 10, match:class discord|equibop|vesktop|whatsapp|discordo"
          "workspace special:todo, match:class Todoist"
        ];

        workspace = [
          "w[tv1]s[false], gapsout:$singleWindowGapsOut"
          "f[1]s[false], gapsout:$singleWindowGapsOut"
        ];
      };
    };
  };
}
