{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

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
        # NOTE: does it matter?
        user = config.telperion.user.name;
      };
    };
  };
}
