{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.graphical.file-managers.dolphin;
in
{
  options.telperion.programs.graphical.file-managers.dolphin = {
    enable = lib.mkEnableOption "Dolphin File Manager";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ libsForQt5.dolphin ];
  };
}
