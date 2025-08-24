{ lib
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
          hyprland = {
            enable = true;
            enableDebug = true;

            prependConfig = ''
              # Configure the built-in laptop display
              # Format: monitor = <name>,<resolution>,<offset>,<scale>
              monitor = , 1920x1080@60, auto, 0.8
            '';
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
