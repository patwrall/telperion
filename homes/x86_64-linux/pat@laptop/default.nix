{ lib
, ...
}:
let
  inherit (lib.telperion) enabled disabled;
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
          grok-bot = enabled;
          iloader = enabled;
          obsidian = enabled;
          rnote = enabled;
          sioyek = enabled;
          vesktop = enabled;
          zotero = enabled;
        };
        browsers = {
          zen-browser = enabled;
        };
        quickshell = {
          ambxst = enabled;
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
            sshAgentVaults = [ "Personal" "Development" ];
          };
          # The codex module reads home.file.".codex/config.toml".source, which
          # home-manager only defines when codex settings are non-empty. They
          # are empty here because the mcp module is off on this host, so
          # leaving codex enabled aborts evaluation.
          codex = disabled;
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

  home.stateVersion = "26.11";
}
