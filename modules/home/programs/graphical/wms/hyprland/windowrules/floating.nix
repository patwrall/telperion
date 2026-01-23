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
          # Simple float by class
          "float on, match:class guifetch"
          "float on, match:class yad"
          "float on, match:class zenity"
          "float on, match:class wev"
          "float on, match:class org\\.gnome\\.FileRoller"
          "float on, match:class file-roller"
          "float on, match:class blueman-manager"
          "float on, match:class com\\.github\\.GradienceTeam\\.Gradience"
          "float on, match:class feh"
          "float on, match:class imv"
          "float on, match:class system-config-printer"
          "float on, match:class org\\.quickshell"

          # Float, resize and center
          "float on, match:class foot, match:title nmtui"
          "size 60% 70%, match:class foot, match:title nmtui"
          "center 1, match:class foot, match:title nmtui"

          "float on, match:class org\\.gnome\\.Settings"
          "size 70% 80%, match:class org\\.gnome\\.Settings"
          "center 1, match:class org\\.gnome\\.Settings"

          "float on, match:class org\\.pulseaudio\\.pavucontrol|yad-icon-browser"
          "size 60% 70%, match:class org\\.pulseaudio\\.pavucontrol|yad-icon-browser"
          "center 1, match:class org\\.pulseaudio\\.pavucontrol|yad-icon-browser"

          "float on, match:class nwg-look"
          "size 50% 60%, match:class nwg-look"
          "center 1, match:class nwg-look"

          # Dialogs
          "float on, match:title (Select|Open)( a)? (File|Folder)(s)?"
          "float on, match:title File (Operation|Upload)( Progress)?"
          "float on, match:title .* Properties"
          "float on, match:title Export Image as PNG"
          "float on, match:title GIMP Crash Debug"
          "float on, match:title Save As"
          "float on, match:title Library"

          # Steam Friends List
          "float on, match:title Friends List, match:class steam"

          # ATLauncher console
          "float on, match:class com-atlauncher-App, match:title ATLauncher Console"
        ];
      };
    };
  };
}
