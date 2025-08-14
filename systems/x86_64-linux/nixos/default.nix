{ lib, ... }:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [ ./hardware.nix ];

  telperion = {
    nix = enabled;

    hardware = { };

    programs = {
      graphical = {
        addons = { };
        wms = {
          hyprland.enable = true;
        };
      };
    };

    security = { };

    services = {
      avahi = enabled;
      geoclue = enabled;
      power = enabled;
    };

    system = {
      boot = {
        enable = true;
        secureBoot = true;
        silentBoot = true;
      };

      networking = {
        enable = true;
        optimizeTcp = true;
      };
      xkb = enabled;
    };

    suites = {
      common = enabled;
      desktop = enabled;

      development = {
        enable = true;
        dockerEnable = true;
      };
    };

    user = {
      initialPassword = "test";
    };
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  system.stateVersion = "25.05";
}
