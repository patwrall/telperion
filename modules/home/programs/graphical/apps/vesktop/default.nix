{ config
, lib
, ...
}:
let
  cfg = config.telperion.programs.graphical.apps.vesktop;
in
{
  options.telperion.programs.graphical.apps.vesktop = {
    enable = lib.mkEnableOption "Vesktop";
  };

  config = lib.mkIf cfg.enable {
    programs.vesktop = {
      enable = true;

      settings = {
        discordBranch = "stable";
        minimizeToTray = false;
        arRPC = true;
        customTitleBar = false;
      };

      vencord = {
        settings = {
          # Can't auto update on nix
          autoUpdate = false;
          autoUpdateNotification = false;

          useQuickCss = true;
          themeLinks = [ ];
          eagerPatches = false;
          enableReactDevtools = true;
          frameless = false;
          transparent = true;
          winCtrlQ = false;
          disableMinSize = true;
          winNativeTitleBar = false;
          plugins = {
            CommandsAPI = {
              enabled = true;
            };
            MessageAccessoriesAPI = {
              enabled = true;
            };
            UserSettingsAPI = {
              enabled = true;
            };
            AlwaysAnimate = {
              enabled = true;
            };
            AlwaysExpandRoles = {
              enabled = true;
            };
            AlwaysTrust = {
              enabled = true;
            };
            BetterSessions = {
              enabled = true;
            };
            CrashHandler = {
              enabled = true;
            };
            FakeNitro = {
              enabled = true;
            };
            FixImagesQuality = {
              enabled = true;
            };
            GameActivityToggle = {
              enabled = true;
            };
            MessageClickActions = {
              enabled = true;
            };
            PlatformIndicators = {
              enabled = true;
            };
            ReplyTimestamp = {
              enabled = true;
            };
            ShowHiddenChannels = {
              enabled = true;
            };
            ShowHiddenThings = {
              enabled = true;
            };
            VencordToolbox = {
              enabled = true;
            };
            WebKeybinds = {
              enabled = true;
            };
            WebScreenShareFixes = {
              enabled = true;
            };
            YoutubeAdblock = {
              enabled = true;
            };
            BadgeAPI = {
              enabled = true;
            };
            VoiceMessages = {
              enabled = true;
            };
            VolumeBooster = {
              enabled = true;
            };
            NoTrack = {
              enabled = true;
              disableAnalytics = true;
            };
            Settings = {
              enabled = true;
              settingsLocation = "aboveNitro";
            };
          };
          notifications = {
            timeout = 5000;
            position = "bottom-right";
            useNative = "not-focused";
            logLimit = 50;
          };
        };
      };
    };
  };
}
