{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.browsers.zen-browser;

in
{
  options.telperion.programs.graphical.browsers.zen-browser = {
    enable = mkEnableOption "zen-browser";
  };

  config = mkIf cfg.enable {
    programs.zen-browser = {
      enable = true;
    };
  };
}
