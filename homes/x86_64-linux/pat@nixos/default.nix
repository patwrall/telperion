{ config
, lib
, ...
}:
let
  inherit (lib) getExe;
  inherit (lib.telperion) enabled;
in
{
  telperion = {
    user = {
      enable = true;
      name = "pat";
    };

    programs = {
      graphical = {
        quickshell = {
          caelestia = enabled;
        };
        wms = {
          hyprland = enabled;
        };
      };
    };

    system = {
      xdg = enabled;
    };
  };
}
