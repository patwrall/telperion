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
          "workspace special:sysmon, class:btop"
          "workspace special:music, class:feishin|Spotify|Supersonic|spotify_player"
          "workspace special:music, initialTitle:Spotify( Free)?" # Spotify wayland, it has no class for some reason
          "workspace special:communication, class:discord|equibop|vesktop|whatsapp|discordo"
          "workspace special:todo, class:Todoist"
        ];

        workspace = [
          "w[tv1]s[false], gapsout:$singleWindowGapsOut"
          "f[1]s[false], gapsout:$singleWindowGapsOut"
        ];
      };
    };
  };
}
