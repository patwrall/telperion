{ lib
, pkgs
, config
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.services.ddccontrol;
in
{
  options.telperion.services.ddccontrol = {
    enable = lib.mkEnableOption "ddccontrol";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      ddcui
      ddcutil
    ];

    services.ddccontrol = {
      enable = true;
    };
  };
}
