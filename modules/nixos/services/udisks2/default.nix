{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) mkBoolOpt;

  cfg = config.telperion.services.udisks2;
in
{
  options.telperion.services.udisks2 = {
    enable = mkBoolOpt true "Whether or not to enable udisks2 service.";
  };

  config = mkIf cfg.enable {
    services.udisks2 = {
      enable = true;
    };
  };
}
