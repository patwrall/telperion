{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.chatgpt-desktop;

in
{
  options.telperion.programs.graphical.apps.chatgpt-desktop = {
    enable = mkEnableOption "chatgpt-desktop";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.telperion.chatgpt-desktop ];
  };
}
