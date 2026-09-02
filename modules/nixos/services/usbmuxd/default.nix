{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.services.usbmuxd;
in
{
  options.telperion.services.usbmuxd = {
    enable = lib.mkEnableOption "usbmuxd support (USB access to iOS devices)";
  };

  config = mkIf cfg.enable { services.usbmuxd.enable = true; };
}
