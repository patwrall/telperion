{ ...
}:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "polkit-gnome-authentication-agent-1"

      "wl-paste --type text --watch cliphist store"
      "wl-paste --type image --watch cliphist store"

      "hyprctl setcursor sweet-cursors 24"
      # "gsettings set org.gnome.desktop.interface cursor-theme 'sweet-cursors'"
    ];
  };
} 
