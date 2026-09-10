{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.grok-bot;

in
{
  options.telperion.programs.graphical.apps.grok-bot = {
    enable = mkEnableOption "grok-bot";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.telperion.grok-bot ];
  };
}
