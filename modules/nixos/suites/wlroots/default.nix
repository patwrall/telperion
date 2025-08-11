{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.wlroots;
in
{
  options.telperion.suites.wlroots = {
    enable = lib.mkEnableOption "common wlroots configuration";
  };

  config = mkIf cfg.enable {

    telperion = {
      services = {
        seatd = mkDefault enabled;
      };
    };
    programs = {
      xwayland.enable = mkDefault true;

      wshowkeys = {
        enable = mkDefault true;
        package = pkgs.wshowkeys;
      };
    };
  };
}
