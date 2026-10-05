# Herm's root access and self-management of this host.
#
# Root is only reachable as `sudo bash -c "…"`. Hermes always asks for
# approval before running `bash -c`, so every root command shows up in
# Discord first. Approve with "once", never "always": "always" would
# allowlist `bash -c` and remove the gate.
#
# The gate checks the command Herm submits, not what scripts it runs, so it
# catches mistakes, not a deliberate bypass (e.g. sudo inside a script).
{ lib, ... }:
let
  repo = "/var/lib/hermes/workspace/telperion";
in
{
  security.sudo.extraRules = [
    {
      users = [ "hermes" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/bash -c *";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # sudo needs setuid binaries (NoNewPrivileges) and a writable system
  # (ProtectSystem) for anything it runs as root, e.g. switching generations.
  systemd.services = lib.genAttrs [ "hermes-agent" "hermes-backend" ] (_: {
    serviceConfig = {
      NoNewPrivileges = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
    };
  });

  # Let Herm evaluate and build configs without root
  nix.settings.allowed-users = [ "hermes" ];

  # Pat pulls Herm's commits from this checkout over the tailnet
  programs.git = {
    enable = true;
    config.safe.directory = [ repo ];
  };

  services.hermes-agent = {
    # No AI auto-approval: every flagged command waits for Pat
    settings.approvals.mode = "manual";

    workingDirectory = "/var/lib/hermes/workspace";
    documents."AGENTS.md" = ./hermes-agents.md;
  };
}
