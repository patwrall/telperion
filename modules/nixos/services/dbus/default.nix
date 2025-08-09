{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) mkBoolOpt;

  cfg = config.telperion.services.dbus;
in
{
  options.telperion.services.dbus = {
    enable = mkBoolOpt true "Whether or not to enable dbus service.";
  };

  config = mkIf cfg.enable {
    services.dbus = {
      enable = true;

      implementation = "broker";
    };
  };
}
