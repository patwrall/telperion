{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkForce;

  cfg = config.telperion.services.seatd;
in
{
  options.telperion.services.seatd = {
    enable = mkEnableOption "seatd";
  };

  config = mkIf cfg.enable {
    services = {
      seatd = {
        enable = true;
        user = config.telperion.user.name;
      };
    };

    # The NixOS seatd module uses s6-notify-socket-from-fd to bridge seatd's
    # fd-1 ready notification to systemd's NOTIFY_SOCKET. This bridge is broken
    # in some nixpkgs versions (signal never reaches systemd → 90s timeout →
    # seatd killed and restarted mid-session). Force Type=simple so systemd
    # considers seatd ready immediately on process start, matching actual
    # behavior since seatd binds its socket before logging "seatd started".
    systemd.services.seatd.serviceConfig.Type = mkForce "simple";
  };
}
