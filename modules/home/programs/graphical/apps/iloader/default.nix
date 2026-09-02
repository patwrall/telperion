{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.iloader;

in
{
  options.telperion.programs.graphical.apps.iloader = {
    enable = mkEnableOption "iloader";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      iloader
    ];
  };
}
