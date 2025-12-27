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
          obsidian = enabled;
          rnote = enabled;
          sioyek = enabled;
          vesktop = enabled;
          zotero = enabled;
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
            prependConfig = ''
              monitor=DP-1,3440x1440@180,0x0,1
              '';
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
      development = {
        enable = true;
        cudaEnable = true;
      };
      music = enabled;
    };
  };

  home.stateVersion = "26.05";
}
