{ config
, lib
, pkgs
, ...
}:
let

  cfg = config.telperion.security.sudo-rs;
in
{
  options.telperion.security.sudo-rs = {
    enable = lib.mkEnableOption "replacing sudo with sudo-rs";
  };

  config = lib.mkIf cfg.enable {
    security.sudo-rs = {
      enable = true;
      package = pkgs.sudo-rs;

      wheelNeedsPassword = false;

      # extraRules = [
      #   {
      #     noPass = true;
      #     users = [ config.telperion.user.name ];
      #   }
      # ];
    };
  };
}
