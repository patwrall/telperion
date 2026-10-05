# X growth: Herm finds fresh posts from target accounts through
# twitterapi.io and drafts replies that Pat posts by hand.
#
# Private data (target list, voice skill, reply log) lives in
# /var/lib/hermes/x and never in this public repo. Only code lives here.
{ pkgs, ... }:
{
  systemd.tmpfiles.rules = [ "d /var/lib/hermes/x 2770 hermes hermes -" ];

  services.hermes-agent = {
    # Herm's terminal and cron scripts strip API keys unless allowlisted
    settings.terminal.env_passthrough = [ "TWITTERAPI_IO_KEY" ];
    extraPackages = [ pkgs.python3 ];
    hermesHomeFiles."scripts/x_discover.py" = ./x/discover.py;
  };
}
