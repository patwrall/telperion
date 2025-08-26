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
        browsers = {
          zen-browser = enabled;
        };
        quickshell = {
          caelestia = enabled;
        };
        wms = {
          hyprland = {
            enable = true;
            enableDebug = true;
          };
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
