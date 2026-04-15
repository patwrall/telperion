{ config
, lib
, ...
}:
let
  cfg = config.telperion.security.usbguard;
in
{
  options.telperion.security.usbguard = {
    enable = lib.mkEnableOption "default usbguard configuration";
  };

  config = lib.mkIf cfg.enable {
    services.usbguard = {
      IPCAllowedUsers = [
        "root"
        "${config.telperion.user.name}"
      ];
      presentDevicePolicy = "allow";
      rules = ''
        allow with-interface equals { 08:*:* }

        # Reject devices with suspicious combination of interfaces
        reject with-interface all-of { 08:*:* 03:00:* }
        reject with-interface all-of { 08:*:* 03:01:* }
        reject with-interface all-of { 08:*:* e0:*:* }
        reject with-interface all-of { 08:*:* 02:*:* }

        # ESP32 / embedded dev board USB-UART chips
        allow id 10c4:ea60  # SiLabs CP2102/CP2104
        allow id 10c4:ea70  # SiLabs CP2105
        allow id 1a86:7523  # WCH CH340
        allow id 1a86:5523  # WCH CH341
        allow id 0403:6001  # FTDI FT232RL
        allow id 0403:6010  # FTDI FT2232
        allow id 0403:6011  # FTDI FT4232
        allow id 303a:1001  # Espressif USB JTAG/serial (ESP32-S3/C3 built-in)
      '';
    };
  };
}
