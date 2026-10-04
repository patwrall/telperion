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

    settings.model = {
      provider = "claude-subscription-directsdk-experimental";
      default = "sonnet";
    };

    # CLAUDE_CODE_OAUTH_TOKEN (from `claude setup-token`), DISCORD_BOT_TOKEN
    # and DISCORD_ALLOWED_USERS; activation merges it into the service's .env.
    # No ANTHROPIC_* overrides: the plugin refuses to run with them set.
    environmentFiles = [ "/var/lib/secrets/hermes.env" ];
  };
}
