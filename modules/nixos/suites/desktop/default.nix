{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.desktop;
in
{
  options.telperion.suites.desktop = {
    enable = lib.mkEnableOption "common desktop config";
  };

  config = mkIf cfg.enable {
    telperion = {
      programs = {
        graphical = {
          addons = {
            weylus = enabled;
          };

          apps = {
            _1password = mkDefault enabled;
          };
        };
      };

      services = {
        flatpak = mkDefault enabled;
      };
    };
  };
}
