{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.graphical.file-managers.nautilus;
in
{
  options.telperion.programs.graphical.file-managers.nautilus = {
    enable = lib.mkEnableOption "the gnome file manager";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ nautilus ];

    networking.firewall.extraCommands = "iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns";

    # Enable support for browsing samba shares.
    services.gvfs.enable = true;
  };
}
