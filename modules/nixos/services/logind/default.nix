{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.services.logind;
in
{
  options.telperion.services.logind = {
    enable = mkEnableOption "logind";
  };

  config = mkIf cfg.enable {
    services = {
      logind = {
        killUserProcesses = true;
      };
    };
  };
}
