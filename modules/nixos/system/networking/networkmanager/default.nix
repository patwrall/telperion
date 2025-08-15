{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.system.networking;
in
{
  config = mkIf (cfg.enable && cfg.manager == "networkmanager") {
    telperion.user.extraGroups = [ "networkmanager" ];

    networking = {
      networkmanager = {
        enable = true;

        connectionConfig = {
          # Enable if `mdns` is not handled by avahi
          "connection.mdns" = lib.mkIf (!config.services.avahi.enable) "2";
        };

        plugins = with pkgs; [
          networkmanager-l2tp
          networkmanager-openvpn
          networkmanager-sstp
          networkmanager-vpnc
        ];

        unmanaged = [
          "interface-name:br-*"
          "interface-name:rndis*"
        ]
        ++ lib.optionals config.telperion.services.tailscale.enable [ "interface-name:tailscale*" ]
        ++ lib.optionals config.telperion.virtualisation.podman.enable [ "interface-name:docker*" ];
        # ++ lib.optionals config.telperion.virtualisation.kvm.enable [ "interface-name:virbr*" ];
      };
    };
    # Slows down rebuilds timing out for network.
    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  };
}
