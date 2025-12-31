{ config
, lib
, ...
}:
let
  inherit (lib)
    mkIf
    types
    ;

  cfg = config.telperion.programs.graphical.wms.hyprland;
in
{
  options.telperion.programs.graphical.wms.hyprland = with types; {
    enable = lib.mkEnableOption "Hyprland";
  };

  config = mkIf cfg.enable {
    programs = {
      hyprland = {
        enable = true;
      };
    };
  };
}
