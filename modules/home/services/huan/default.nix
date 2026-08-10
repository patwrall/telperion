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
    llama_url =
      lib.optionalString cfg.intent.llm.enable "http://127.0.0.1:${toString cfg.intent.llm.port}";
    agent_cmd = lib.optionalString cfg.agent.enable "claude";
    brain_model = lib.optionalString (cfg.agent.enable && cfg.brain.enable) cfg.brain.model;
    announce_min_s = cfg.announceMinSeconds;
    heartbeat = cfg.proactive;
    agent_model = cfg.agent.model;
    agent_timeout_s = cfg.agent.timeoutSeconds;
    agent_cwd = cfg.agent.cwd;
    agent_mcp_config = lib.optionalString cfg.agent.enable (toString agentMcpConfig);
    agent_allowed_tools = cfg.agent.allowedTools;
    agent_permission_mode = cfg.agent.permissionMode;
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

  agentMcpConfig = (pkgs.formats.json { }).generate "huan-mcp.json" {
    mcpServers.huan = {
      command = lib.getExe cfg.package;
      args = [ "mcp" ];
    };
  };

  # faster-whisper accepts a local model directory; pinning it here removes
  # the imperative first-run download into ~/.cache/huggingface
  whisperSmallEn = pkgs.linkFarm "faster-whisper-small.en" (
    lib.mapAttrsToList
      (name: sha256: {
        inherit name;
        path = pkgs.fetchurl {
          url = "https://huggingface.co/Systran/faster-whisper-small.en/resolve/main/${name}";
          inherit sha256;
        };
      })
      {
        "config.json" = "1bjz3mk35k4zhc82dr29cybckknsnh13fzqpm0gzdh8aac2rcsk6";
        "model.bin" = "0yp3irv9wk7ymhc8lhcd6xfkjhg06pp366rllnsaqngf0mds9ck2";
        "tokenizer.json" = "1pr25px1bnafw3j29qyqf38k5qdmpjmx2xcanghxqdll8195574j";
        "vocabulary.txt" = "1kqml5svagpwcv5k6xf5392f4p5rszznjnxb69fmk8nk8s3mhxzz";
      }
  );

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
        default = ./models;
        defaultText = "bundled models dir (ships hey_huan)";
        description = "Directory with custom-trained openWakeWord models.";
      };

      port = mkOption {
        type = types.port;
        default = 10400;
        description = "Localhost port for the wyoming-openwakeword service.";
      };

      threshold = mkOption {
        type = types.numbers.between 0.0 1.0;
        default = 0.5;
        description = ''
          Detection threshold. Lower fires more eagerly (better recall,
          more false activations).
        '';
      };
    };

    stt = {
      model = mkOption {
        type = types.str;
        default = toString whisperSmallEn;
        defaultText = "small.en (pinned in the store)";
        description = ''
          faster-whisper model: either a local model directory (the default
          is small.en pinned in the Nix store) or a HuggingFace model name
          like distil-large-v3, which downloads imperatively to
          ~/.cache/huggingface on first load.
        '';
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

    brain = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Conversational brain: a persistent Claude process (haiku-class)
          holding one continuous conversation, fed the live world-state.
          Requires agent.enable for the claude binary.
        '';
      };

      model = mkOption {
        type = types.str;
        default = "haiku";
        description = "Model for the conversational brain.";
      };
    };

    agent = {
      enable = mkEnableOption "the reasoning tier (Claude Code CLI, headless)";

      model = mkOption {
        type = types.str;
        default = "sonnet";
        description = "Model passed to the Claude CLI for delegated tasks.";
      };

      timeoutSeconds = mkOption {
        type = types.ints.positive;
        default = 300;
        description = "Hard limit on a single delegated task.";
      };

      cwd = mkOption {
        type = types.str;
        default = "~";
        description = "Working directory for the agent (loads that dir's CLAUDE.md).";
      };

      permissionMode = mkOption {
        type = types.str;
        default = "acceptEdits";
        description = "Claude CLI permission mode for headless runs.";
      };

      allowedTools = mkOption {
        type = types.listOf types.str;
        default = [
          "Read"
          "Grep"
          "Glob"
          "LS"
          "WebSearch"
          "WebFetch"
          "Bash"
          "mcp__huan"
        ];
        description = "Tools the headless agent may use without prompting.";
      };
    };

    intent.llm = {
      enable = mkEnableOption "conversational intent routing via a local llama.cpp server";

      model = mkOption {
        type = types.path;
        default = pkgs.fetchurl {
          url = "https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf";
          sha256 = "151z4lirvp9mj8id869i2z1vr0b023v5n96hi5dvvax3j6imd7ww";
        };
        defaultText = "Qwen2.5-3B-Instruct Q4_K_M (fetched)";
        description = "GGUF model for the intent router.";
      };

      port = mkOption {
        type = types.port;
        default = 10401;
        description = "Localhost port for the llama.cpp server.";
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

    proactive = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Proactive brain heartbeats on notable events (e.g. a command
        failing repeatedly): the brain may speak one helpful line or
        choose silence. Rate-limited to one per two minutes.
      '';
    };

    announceMinSeconds = mkOption {
      type = types.ints.unsigned;
      default = 60;
      description = ''
        Proactively announce shell commands that ran at least this long
        when they finish. 0 disables announcements.
      '';
    };

    shellHook = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Report shell commands (start/end, cwd, exit, duration) to the
        daemon from fish, giving huan live awareness of builds and
        long-running commands. Fire-and-forget; the shell never blocks.
      '';
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

    systemd.user.services = {
      huan = {
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

      huan-llama = mkIf cfg.intent.llm.enable {
        Unit = {
          Description = "llama.cpp intent router for huan";
          PartOf = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe' (pkgs.llama-cpp.override { cudaSupport = true; }) "llama-server")
            "--model ${cfg.intent.llm.model}"
            "--port ${toString cfg.intent.llm.port}"
            "--host 127.0.0.1"
            "-ngl 99"
            "--ctx-size 2048"
            "--no-webui"
          ];
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install.WantedBy = [ "graphical-session.target" ];
      };

      huan-compact = {
        Unit.Description = "huan nightly episodic compaction";
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe cfg.package} compact";
        };
      };

      huan-openwakeword = mkIf cfg.wakeWord.enable {
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
              "--threshold ${toString cfg.wakeWord.threshold}"
            ]
            ++ lib.optional (cfg.wakeWord.customModelDir != null)
              "--custom-model-dir ${cfg.wakeWord.customModelDir}"
          );
          Restart = "on-failure";
          RestartSec = 5;
        };

        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

    systemd.user.timers.huan-compact = {
      Unit.Description = "huan nightly episodic compaction";
      Timer = {
        OnCalendar = "04:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    programs.fish.interactiveShellInit = lib.mkIf cfg.shellHook ''
      function __huan_preexec --on-event fish_preexec
        set -g __huan_id (random)(random)
        set -g __huan_t0 (date +%s.%N)
        ${lib.getExe cfg.package} shellev start $__huan_id - - $PWD -- $argv[1] &>/dev/null &
        disown 2>/dev/null
      end
      function __huan_postexec --on-event fish_postexec
        set -l st $status
        set -q __huan_t0; or return
        set -l dur (math (date +%s.%N) - $__huan_t0)
        ${lib.getExe cfg.package} shellev end $__huan_id $st $dur $PWD -- $argv[1] &>/dev/null &
        disown 2>/dev/null
      end
    '';

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
