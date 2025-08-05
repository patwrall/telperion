{ config, pkgs, ... }:
{
  programs.hyprland = {
    enable = true;

    settings = {
      monitor = "Virtual-1,1920x1080@60,0x0,1";

      "$mod" = "SUPER";

      exec-once = [ "kitty" ];

      bind = [
        "$mod, RETURN, exec, kitty"
        "$mod_SHIFT, Q, exit"
      ];

      misc.vrr = 1;
    };
  };

  home.packages = with pkgs; [
    hyprland
    kitty
  ];
}
