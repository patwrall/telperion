{ lib, ... }:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [ ./hardware.nix ];

  telperion = {
    nix = enabled;

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
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  system.stateVersion = "25.05";
}
