{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.hardware.fingerprint;
in
{
  options.telperion.hardware.fingerprint = {
    enable = lib.mkEnableOption "fingerprint support";
  };

  config = mkIf cfg.enable { services.fprintd.enable = true; };
}
