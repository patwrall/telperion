{ config
, lib
, ...
}:
let
  cfg = config.telperion.services.openssh;

  inherit (lib) mkEnableOption mkIf;
in
{
  options.telperion.services.openssh = {
    enable = mkEnableOption "OpenSSH server";
  };

  config = mkIf cfg.enable {
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
