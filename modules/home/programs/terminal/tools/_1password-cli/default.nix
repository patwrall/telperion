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
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      age-plugin-1p
      _1password-cli
    ];

    home.sessionVariables = mkIf cfg.enableSshSocket {
      SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
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
