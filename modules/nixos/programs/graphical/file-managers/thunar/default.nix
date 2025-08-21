{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.graphical.file-managers.thunar;
in
{
  options.telperion.programs.graphical.file-managers.thunar = {
    enable = lib.mkEnableOption "the xfce file manager";
  };

  config = mkIf cfg.enable {
    programs.thunar = {
      enable = true;
    };
  };
}
