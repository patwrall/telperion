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
      apps = {
        _1password = {
          enable = true;
          enableSshSocket = true;
        };
      };
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
      flatpak = enabled;
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
        secureBoot = false;
        silentBoot = true;
      };
      networking = {
        enable = true;
        optimizeTcp = true;
        manager = "networkmanager";
      };
      realtime = enabled;
    };
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  # This laptop is usually on flaky WiFi; the common default of 25 parallel
  # substituter connections overwhelms the link and large NAR downloads get
  # reset mid-transfer. Fewer connections download reliably (nix resumes
  # partial NARs from the last byte offset). Laptop-only override.
  nix.settings.http-connections = lib.mkForce 5;

  system.stateVersion = "26.11";
}
