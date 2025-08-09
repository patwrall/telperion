{ lib
, config
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.services.power;
in
{
  options.telperion.services.power = {
    enable = lib.mkEnableOption "power profiles";
  };

  config = mkIf cfg.enable { services.power-profiles-daemon.enable = cfg.enable; };
}
