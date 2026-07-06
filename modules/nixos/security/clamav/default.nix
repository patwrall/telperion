{ config
, lib
, ...
}:
let
  cfg = config.telperion.security.clamav;
in
{
  options.telperion.security.clamav = {
    enable = lib.mkEnableOption "default clamav configuration";
  };

  config = lib.mkIf cfg.enable {
    services.clamav = {
      daemon = {
        enable = true;
      };

      fangfrisch = {
        enable = true;
      };

      scanner = {
        enable = true;
        interval = "weekly";
        scanDirectories = [
          "/home"
          "/tmp"
          "/var/lib"
          "/var/log"
          "/var/tmp"
        ];
      };

      updater = {
        enable = true;
      };
    };

    # Don't let nixos-rebuild stop or restart an in-progress weekly scan:
    # clamdscan is Type=oneshot, so switch-to-configuration would block
    # synchronously on the full-tree scan (~1h). The timer still fires on
    # schedule; new store-path picks up on the next tick.
    systemd.services.clamdscan = {
      restartIfChanged = false;
      stopIfChanged = false;
    };
  };
}
