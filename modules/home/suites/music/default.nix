{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.music;
in
{
  options.telperion.suites.music = {
    enable = lib.mkEnableOption "common music configuration";
  };

  config = mkIf cfg.enable {
    telperion = {
      programs = {
        graphical.apps = {
          spicetify = mkDefault enabled;
          musescore = mkDefault enabled;
        };
      };
    };
  };
}
