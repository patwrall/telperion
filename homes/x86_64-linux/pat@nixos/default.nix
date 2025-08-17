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
        wms = {
          hyprland = {
            enable = true;
          };
        };
      };
    };

    system = {
      xdg = enabled;
    };
  };
}
