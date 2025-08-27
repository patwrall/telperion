{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.programs.graphical.apps._1password;
in
{
  options.telperion.programs.graphical.apps._1password = {
    enable = lib.mkEnableOption "1password";
    enableSshSocket = lib.mkEnableOption "ssh-agent socket";
  };

  config = mkIf cfg.enable {
    programs = {
      _1password = enabled;
      _1password-gui = {
        enable = true;
        package = pkgs._1password-gui;
        enableSshAgent = true;

        polkitPolicyOwners = [ config.telperion.user.name ];
      };

      ssh.extraConfig = lib.optionalString cfg.enableSshSocket ''
        Host *
          AddKeysToAgent yes
          IdentityAgent ~/.1password/agent.sock
      '';
    };
  };
}
