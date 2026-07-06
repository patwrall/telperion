{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.hardware.logitech;
in
{
  options.telperion.hardware.logitech = {
    enable = lib.mkEnableOption "Logitech wireless device support (Solaar, udev rules)";
  };

  config = mkIf cfg.enable {
    hardware.logitech.wireless = {
      enable = true;
      enableGraphical = true;
    };
  };
}
