{ lib, ... }:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [ ./hardware.nix ];

  telperion = {
    nix = enabled;

    programs = {
      graphical = {
        wms = {
          hyprland.enable = true;
        };
      };
    };

    system = {
      boot = enabled;
      fonts = enabled;
      locale = enabled;
      networking = enabled;
      time = enabled;
      xkb = enabled;
    };

    suites = {
      common = enabled;
    };

    user = {
      initialPassword = "test";
    };
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  system.stateVersion = "25.05";
}
