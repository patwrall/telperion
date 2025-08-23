{ lib
, ...
}:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [ ./hardware.nix ];

  environment.loginShellInit = ''
    if uwsm check may-start; then
      exec uwsm start -- default
    fi
  '';

  telperion = {
    archetypes = {
      personal = enabled;
    };

    hardware = { };

    programs.graphical = {
      wms = {
        hyprland.enable = true;
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
    };

    suites.development = {
      enable = true;
      dockerEnable = true;
    };

    user = {
      initialPassword = "test";
    };
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  system.stateVersion = "25.05";
}
