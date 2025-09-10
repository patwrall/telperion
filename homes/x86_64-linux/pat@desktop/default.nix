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
        apps = {
          zathura = enabled;
          vesktop = enabled;
        };
        browsers = {
          zen-browser = enabled;
        };
        editors = {
          idea = enabled;
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
      terminal = {
        tools = {
          _1password-cli = {
            enable = true;
            enableSshSocket = true;
          };
        };
      };
    };

    system = {
      xdg = enabled;
    };

    suites = {
      common = enabled;
      development = enabled;
      music = enabled;
    };
  };

  home.stateVersion = "25.05";
}
