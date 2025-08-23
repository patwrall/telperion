{ lib
, pkgs
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
              monitor = eDP-1, preferred, 0x0, 1
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
