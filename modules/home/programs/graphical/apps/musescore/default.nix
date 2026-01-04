{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.musescore;

in
{
  options.telperion.programs.graphical.apps.musescore = {
    enable = mkEnableOption "obsidian";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      musescore
      muse-sounds-manager
    ];
  };
}
