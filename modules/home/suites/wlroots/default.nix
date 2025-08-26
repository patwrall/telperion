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
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "wlroots is only available on linux";
      }
    ];

    home.packages = with pkgs; [
      wdisplays
      wl-clipboard
      wl-clip-persist
      wlr-randr
      wl-screenrec
    ];

    telperion = {
      programs = {
        graphical = {
          addons = {
            electron-support = mkDefault enabled;
          };
        };
      };
    };
  };
}
