{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.system.networking;
in
{
  config = mkIf (cfg.enable && cfg.manager == "connman") {
    services.connman = {
      enable = true;

      networkInterfaceBlacklist = [
        "vmnet"
        "vboxnet"
        "virbr"
        "ifb"
        "ve"
      ]
      ++ lib.optionals config.telperion.services.tailscale.enable [ "tailscale*" ]
      ++ lib.optionals config.telperion.virtualisation.podman.enable [ "docker*" ];
    };
  };
}
