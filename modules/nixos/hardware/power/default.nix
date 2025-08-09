{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.hardware.power;
in
{
  options.telperion.hardware.power = {
    enable = lib.mkEnableOption "support for extra power devices";
  };

  config = mkIf cfg.enable {
    services.upower = {
      enable = true;
      percentageAction = 5;
      percentageCritical = 10;
      percentageLow = 25;
    };
  };
}
