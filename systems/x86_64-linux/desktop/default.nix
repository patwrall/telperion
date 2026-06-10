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
    # Wait up to 3 s for the session DBus socket — it's created by the user
    # systemd instance, which starts in parallel with the login shell and
    # typically arrives ~1 s later. uwsm check may-start calls dbus.SessionBus()
    # and fails with an exception (exit 1) if the socket isn't there yet.
    if [ -n "$XDG_RUNTIME_DIR" ]; then
      _uwsm_cnt=0
      until [ -S "$XDG_RUNTIME_DIR/bus" ] || [ "$_uwsm_cnt" -ge 30 ]; do
        sleep 0.1
        _uwsm_cnt=$((_uwsm_cnt + 1))
      done
      unset _uwsm_cnt
    fi
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
      geoclue = enabled;
      mullvad-vpn = enabled;
      openssh = enabled;
      power = enabled;
    };

    suites = {
      desktop = enabled;
      development = {
        enable = true;
        dockerEnable = true;
      };
      games = enabled;
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

  system.stateVersion = "26.11";
}
