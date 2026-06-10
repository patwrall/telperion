{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools._1password-cli;
in
{
  options.telperion.programs.terminal.tools._1password-cli = {
    enable = lib.mkEnableOption "1password-cli";
    enableSshSocket = lib.mkEnableOption "ssh-agent socket";
    sshAgentVaults = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "Personal" ];
      description = "1Password vaults whose SSH keys are served by the agent.";
    };
  };

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        age-plugin-1p
        _1password-cli
      ];

      sessionVariables = mkIf cfg.enableSshSocket {
        SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
      };

      file.".config/1Password/ssh/agent.toml" = mkIf cfg.enableSshSocket {
        text = lib.concatMapStrings
          (vault: ''
            [[ssh-keys]]
            vault = "${vault}"
          '')
          cfg.sshAgentVaults;
      };
    };

    programs = {
      ssh.extraConfig = lib.optionalString cfg.enableSshSocket ''
        Host *
          AddKeysToAgent yes
          IdentityAgent ~/.1password/agent.sock
      '';
    };
  };
}
