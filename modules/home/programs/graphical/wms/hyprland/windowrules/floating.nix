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
          "float, class:guifetch"
          "float, class:yad"
          "float, class:zenity"
          "float, class:wev"
          "float, class:org\\.gnome\\.FileRoller"
          "float, class:file-roller"
          "float, class:blueman-manager"
          "float, class:com\\.github\\.GradienceTeam\\.Gradience"
          "float, class:feh"
          "float, class:imv"
          "float, class:system-config-printer"
          "float, class:org\\.quickshell"

          # Float, resize and center
          "float, class:foot, title:nmtui"
          "size 60% 70%, class:foot, title:nmtui"
          "center 1, class:foot, title:nmtui"
          "float, class:org\\.gnome\\.Settings"
          "size 70% 80%, class:org\\.gnome\\.Settings"
          "center 1, class:org\\.gnome\\.Settings"
          "float, class:org\\.pulseaudio\\.pavucontrol|yad-icon-browser"
          "size 60% 70%, class:org\\.pulseaudio\\.pavucontrol|yad-icon-browser"
          "center 1, class:org\\.pulseaudio\\.pavucontrol|yad-icon-browser"
          "float, class:nwg-look"
          "size 50% 60%, class:nwg-look"
          "center 1, class:nwg-look"

          # Dialogs
          "float, title:(Select|Open)( a)? (File|Folder)(s)?"
          "float, title:File (Operation|Upload)( Progress)?"
          "float, title:.* Properties"
          "float, title:Export Image as PNG"
          "float, title:GIMP Crash Debug"
          "float, title:Save As"
          "float, title:Library"

          # Steam Friends List
          "float, title:Friends List, class:steam"

          # ATLauncher console
          "float, class:com-atlauncher-App, title:ATLauncher Console"
        ];
      };
    };
  };
}
