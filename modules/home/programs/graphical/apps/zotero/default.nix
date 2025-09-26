{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.zotero;

in
{
  options.telperion.programs.graphical.apps.zotero = {
    enable = mkEnableOption "zotero";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      zotero
    ];
  };
}
