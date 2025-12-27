{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.programs.graphical.editors.idea;
in
{
  options.telperion.programs.graphical.editors.idea = {
    enable = mkEnableOption "Whether or not to enable idea";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      jetbrains.idea
      scenebuilder
    ];
  };
}
