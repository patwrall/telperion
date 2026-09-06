{ lib
, pkgs
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
          chatgpt-desktop = enabled;
          gdlauncher = enabled;
          iloader = enabled;
          obsidian = enabled;
          rnote = enabled;
          sioyek = enabled;
          stremio = enabled;
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

    services = {
      huan = {
        enable = false;
        agent = enabled;
        brain = {
          # the pivot: voice-driven Claude Code — the brain works directly
          model = "sonnet";
          collaborator = true;
          tools = with pkgs; [
            gcalcli # Google Calendar (one-time OAuth: gcalcli init)
            himalaya # Gmail via IMAP OAuth2 (one-time setup)
          ];
        };
        intent.llm = disabled;
        # PCsensor FootSwitch sends KEY_PAUSE (code 119, verified via evdev)
        converseBinds = [ ", Pause" ];
        wakeWord = {
          # custom-trained model (modules/home/services/huan/models);
          # low threshold per user preference: fire eagerly, tune up if chatty
          model = "hey_huan";
          threshold = 0.35;
        };
        tts.elevenlabs = {
          enable = true;
          voiceId = "yj30vwTGJxSHezdAGsv9";
          # v3: most expressive, understands [audio tags]; no websocket
          # (HTTP streaming only), slower first-audio than flash/v2 —
          # fillers cover the gap
          modelId = "eleven_v3";
          style = 0.55;
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
