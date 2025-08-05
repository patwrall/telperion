{ pkgs
, ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd = {
      enable = true;
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };
    xwayland = {
      enable = true;
    };

    settings = {

      "$mod" = "SUPER";

      exec-once = [
        "polkit-gnome-authentication-agent-1"
      ];
    };
  };
}

