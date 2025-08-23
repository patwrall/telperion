{ lib
, ...
}:
let
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

    suites = {
      common = enabled;
    };
  };

  home.stateVersion = "25.05";
}
