{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.system.realtime;
in
{
  options.telperion.system.realtime = {
    enable = lib.mkEnableOption "realtime";
  };

  config = mkIf cfg.enable {
    users = {
      users."${config.telperion.user.name}".extraGroups = [ "realtime" ];
      groups.realtime = { };
    };

    services.udev.extraRules = ''
      KERNEL=="cpu_dma_latency", GROUP="realtime"
    '';

    security.pam.loginLimits = [
      {
        domain = "@realtime";
        type = "-";
        item = "rtprio";
        value = 98;
      }
      {
        domain = "@realtime";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
      {
        domain = "@realtime";
        type = "-";
        item = "nice";
        value = -11;
      }
    ];
  };
}
