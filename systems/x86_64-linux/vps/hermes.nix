{ inputs
, pkgs
, ...
}:
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  services.hermes-agent = {
    enable = true;
    # `hermes` CLI on PATH, sharing state with the service
    addToSystemPackages = true;

    # Runs turns on the Claude Pro/Max subscription through the official
    # Claude Code CLI. Pinned to the commit the Hermes plugin catalog reviewed.
    extraPlugins = [
      (pkgs.fetchFromGitHub {
        name = "claude-subscription-directsdk";
        owner = "NousResearch";
        repo = "hermes-plugin-claude-subscription-directsdk";
        rev = "602393b6d3ea148bc618cd23da1a13fa332e1433";
        hash = "sha256-Ll0bmt+UJONvDPrfFTECVvlut/MgQIBmInYgtjYAoC0=";
      })
    ];
    # The plugin looks `claude` up on PATH when it loads, before Hermes reads .env
    extraPackages = [ pkgs.claude-code ];

    settings = {
      model = {
        provider = "claude-subscription-directsdk-experimental";
        default = "opus";
      };
      # Speaks replies to voice memos (`/voice on` in Discord) and transcribes them
      tts = {
        provider = "elevenlabs";
        elevenlabs = {
          voice_id = "21m00Tcm4TlvDq8ikWAM"; # Rachel
          model_id = "eleven_v4_turbo";
        };
      };
      stt.provider = "elevenlabs";
      # Cron schedules and "today" follow Pat's clock, not the server's UTC
      timezone = "America/Chicago";
    };

    hermesHomeFiles = {
      "SOUL.md" = ./SOUL.md;
      # Run by the hourly watchdog cron job (`--no-agent --script watchdog.sh`)
      "scripts/watchdog.sh" = ./hermes-watchdog.sh;
    };

    # Web dashboard, password-protected; 9119 isn't open publicly, so it's
    # reachable only over the tailnet at http://vps:9119
    backend = {
      mode = "dashboard";
      host = "0.0.0.0";
    };

    # CLAUDE_CODE_OAUTH_TOKEN (from `claude setup-token`), DISCORD_BOT_TOKEN,
    # DISCORD_ALLOWED_USERS, ELEVENLABS_API_KEY and HERMES_DASHBOARD_BASIC_AUTH_
    # {USERNAME,PASSWORD,SECRET}; activation merges it into the service's .env.
    # No ANTHROPIC_* overrides: the plugin refuses to run with them set.
    environmentFiles = [ "/var/lib/secrets/hermes.env" ];

    # Home channel for cron/notifications. /sethome writes config.yaml and
    # .env, which activation rewrites, so pin it here instead.
    environment = {
      DISCORD_HOME_CHANNEL = "1555434806962167858"; # Private / #hermes
      DISCORD_HOME_CHANNEL_NAME = "#hermes";
    };
  };
}
