{ config
, lib
, ...
}:
let

  cfg = config.telperion.suites.development;
in
{
  options.telperion.suites.development = {
    enable = lib.mkEnableOption "common development configuration";
    dockerEnable = lib.mkEnableOption "docker development configuration";
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      12345
      3000
      3001
      8080
      8081
    ];

    telperion = {
      user = {
        extraGroups = [ "git" ];
      };

      virtualisation = {
        podman.enable = cfg.dockerEnable;
      };
    };
  };
}
