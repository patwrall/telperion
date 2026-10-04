{ config
, hostname
, ...
}:
{
  networking = {
    hostName = hostname;
    useDHCP = false;
    useNetworkd = true;

    # Anything listening is reachable over the tailnet; publicly only SSH is open.
    firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
  };

  # OVH serves IPv4 over DHCP. IPv6 is a static /128 whose gateway lies outside
  # it, hence GatewayOnLink. Values from the OVH delivery email / control panel.
  systemd.network.networks."30-wan" = {
    matchConfig.Name = "en* eth*";
    networkConfig.DHCP = "ipv4";
    address = [ "2001:41d0:801:2000::49aa/128" ];
    routes = [
      {
        Gateway = "2001:41d0:801:2000::1";
        GatewayOnLink = true;
      }
    ];
  };

  services.tailscale = {
    enable = true;
    # Single-use auth key, only read for the first `tailscale up`
    authKeyFile = "/var/lib/secrets/tailscale-authkey";
    openFirewall = true;
  };
}
