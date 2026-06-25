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
          gdlauncher = enabled;
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
          ambxst = enabled;
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
            sshAgentVaults = [ "Personal" "Development" ];
          };
          mcp = {
            enable = true;
            canvas = {
              enable = true;
              apiUrl = "https://ivylearn.ivytech.edu/api/v1";
            };
            discord = {
              enable = true;
              guildId = "1497351886624260128";
            };
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

  home.stateVersion = "26.11";
}
