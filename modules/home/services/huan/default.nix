{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.telperion.services.huan;

  wakeUri = "tcp://127.0.0.1:${toString cfg.wakeWord.port}";

  daemonConfig = (pkgs.formats.json { }).generate "huan.json" {
    stt_model = cfg.stt.model;
    stt_device = cfg.stt.device;
    wake_enabled = cfg.wakeWord.enable;
    wake_uri = wakeUri;
    wake_names = [ cfg.wakeWord.model ];
    silence_ms = cfg.capture.silenceMs;
    followup_s = cfg.capture.followupSeconds;
    tts_voice = if cfg.tts.voice == null then "" else toString cfg.tts.voice;
    eleven_voice_id = lib.optionalString cfg.tts.elevenlabs.enable cfg.tts.elevenlabs.voiceId;
    eleven_model_id = cfg.tts.elevenlabs.modelId;
    eleven_api_key_file = lib.optionalString cfg.tts.elevenlabs.enable cfg.tts.elevenlabs.apiKeyFile;
    eleven_stability = cfg.tts.elevenlabs.stability;
    eleven_similarity = cfg.tts.elevenlabs.similarityBoost;
    eleven_style = cfg.tts.elevenlabs.style;
    eleven_speaker_boost = cfg.tts.elevenlabs.speakerBoost;
  };

  huanCtl = "${lib.getExe cfg.package} ctl";

  # piper requires the .onnx.json config next to the model, same basename
  defaultVoice = pkgs.linkFarm "piper-voice-lessac-medium" [
    {
      name = "en_US-lessac-medium.onnx";
      path = pkgs.fetchurl {
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx";
        hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
      };
    }
    {
      name = "en_US-lessac-medium.onnx.json";
      path = pkgs.fetchurl {
        url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json";
        hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
      };
    }
  ];
in
{
  options.telperion.services.huan = {
    enable = mkEnableOption "huan voice agent";

    package = mkOption {
      type = types.package;
      default = pkgs.telperion.huan.override { withCuda = cfg.stt.device == "cuda"; };
      defaultText = "pkgs.telperion.huan, with CUDA when stt.device is cuda";
      description = "The huan daemon package.";
    };

    wakeWord = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Run wyoming-openwakeword and listen for the wake word (CPU only).";
      };

      model = mkOption {
        type = types.str;
        default = "hey_jarvis";
        description = ''
          Wake word model name. Either one of openWakeWord's bundled models
          (hey_jarvis, alexa, hey_mycroft, ...) or the filename stem of a
          custom model placed in {option}`wakeWord.customModelDir`.
        '';
      };

      customModelDir = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Directory with custom-trained openWakeWord models.";
      };

      port = mkOption {
        type = types.port;
        default = 10400;
        description = "Localhost port for the wyoming-openwakeword service.";
      };
    };

    stt = {
      model = mkOption {
        type = types.str;
        default = "small.en";
        description = "faster-whisper model name (e.g. small.en, distil-large-v3).";
      };

      device = mkOption {
        type = types.enum [ "cuda" "cpu" ];
        default = "cuda";
        description = "Device faster-whisper runs on.";
      };
    };

    capture = {
      silenceMs = mkOption {
        type = types.ints.positive;
        default = 450;
        description = ''
          Trailing silence (ms) before an utterance is considered finished.
          This is the fixed floor of post-speech latency; lower is snappier
          but risks cutting off mid-pause.
        '';
      };

      followupSeconds = mkOption {
        type = types.ints.unsigned;
        default = 5;
        description = ''
          After a voice command, keep listening this long for a chained
          command without requiring the wake word again. 0 disables.
        '';
      };
    };

    tts = {
      voice = mkOption {
        type = types.nullOr types.path;
        default = "${defaultVoice}/en_US-lessac-medium.onnx";
        defaultText = "en_US-lessac-medium (fetched)";
        description = ''
          Piper voice model (.onnx), used as the sole TTS when ElevenLabs
          is disabled and as the offline fallback when it is enabled.
          Null disables spoken acknowledgments.
        '';
      };

      elevenlabs = {
        enable = mkEnableOption "ElevenLabs as the primary TTS (piper falls back)";

        voiceId = mkOption {
          type = types.str;
          default = "21m00Tcm4TlvDq8ikWAM"; # Rachel
          description = "ElevenLabs voice id.";
        };

        modelId = mkOption {
          type = types.str;
          default = "eleven_flash_v2_5";
          description = "ElevenLabs model id. Flash is the low-latency tier.";
        };

        apiKeyFile = mkOption {
          type = types.str;
          default = "~/.config/huan/elevenlabs-key";
          description = ''
            Path to a file containing only the ElevenLabs API key.
            Point this at a sops-nix or opnix secret path once wired;
            a plain chmod-600 file works meanwhile.
          '';
        };

        stability = mkOption {
          type = types.numbers.between 0.0 1.0;
          default = 0.4;
          description = "Lower = more emotional variation between renditions.";
        };

        similarityBoost = mkOption {
          type = types.numbers.between 0.0 1.0;
          default = 0.75;
          description = "Adherence to the original voice.";
        };

        style = mkOption {
          type = types.numbers.between 0.0 1.0;
          default = 0.4;
          description = "Style exaggeration; higher is more expressive but adds latency.";
        };

        speakerBoost = mkOption {
          type = types.bool;
          default = true;
          description = "Boost similarity to the original speaker.";
        };
      };
    };

    ptt = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Add a Hyprland push-to-talk keybind (hold to record).";
      };

      bind = mkOption {
        type = types.str;
        default = "SUPER, V";
        description = "Hyprland mod+key for push-to-talk.";
      };
    };

    sleepToggleBind = mkOption {
      type = types.nullOr types.str;
      default = "SUPER_SHIFT, V";
      description = ''
        Hyprland mod+key toggling the manual VRAM sleep (unloads/reloads
        the GPU models; wake word detection stays on CPU). Null disables.
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.huan = {
      Unit = {
        Description = "huan voice agent daemon (reflex tier)";
        After = [ "graphical-session.target" ]
          ++ lib.optional cfg.wakeWord.enable "huan-openwakeword.service";
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${lib.getExe cfg.package} daemon --config ${daemonConfig}";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.huan-openwakeword = mkIf cfg.wakeWord.enable {
      Unit = {
        Description = "wyoming-openwakeword wake word detector for huan";
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe pkgs.wyoming-openwakeword)
            "--uri ${wakeUri}"
            "--preload-model ${cfg.wakeWord.model}"
          ]
          ++ lib.optional (cfg.wakeWord.customModelDir != null)
            "--custom-model-dir ${cfg.wakeWord.customModelDir}"
        );
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    wayland.windowManager.hyprland.extraConfig = lib.concatStringsSep "\n" (
      lib.optionals cfg.ptt.enable [
        "bind = ${cfg.ptt.bind}, exec, ${huanCtl} ptt-start"
        "bindr = ${cfg.ptt.bind}, exec, ${huanCtl} ptt-stop"
      ]
      ++ lib.optional (cfg.sleepToggleBind != null)
        "bind = ${cfg.sleepToggleBind}, exec, ${huanCtl} toggle"
    );
  };
}
