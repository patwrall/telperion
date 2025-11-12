{ config
, lib
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.programs.graphical.apps.spicetify;
in
{
  options.telperion.programs.graphical.apps.spicetify = {
    enable = mkEnableOption "Spicetify";
  };

  config = mkIf cfg.enable {
    programs.spicetify = {
      enable = true;
    };
  };
}
