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
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        windowrule = [
          "workspace special:sysmon, match:class btop"
          "workspace special:music, match:class feishin|Spotify|Supersonic|spotify_player"
          "workspace special:music, match:initial_title Spotify( Free)?"
          "workspace special:communication, match:class discord|equibop|vesktop|whatsapp|discordo"
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
