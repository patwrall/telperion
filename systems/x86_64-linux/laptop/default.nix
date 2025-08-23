{ lib
, ...
}:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
    ./network.nix
  ];

  environment.loginShellInit = ''
    if uwsm check may-start; then
      exec uwsm start -- default
    fi
  '';

  telperion = {
    nix = enabled;

    archetypes = {
      personal = enabled;
    };

    programs.graphical = {
      wms = {
        hyprland.enable = true;
      };
    };

    security = {
      keyring = enabled;
      sudo-rs = enabled;
    };

    services = {
      avahi = enabled;
      geoclue = enabled;
      power = enabled;
    };

    suites.development = {
      enable = true;
      dockerEnable = true;
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
      realtime = enabled;
    };
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  system.stateVersion = "25.05";
}
