{ lib
, pkgs
, config
, ...
}:
let
  inherit (lib) types mkIf;

  cfg = config.telperion.services.mullvad-vpn;
in
{
  options.telperion.services.mullvad-vpn = with types; {
    enable = lib.mkEnableOption "mullvad";
  };

  config = mkIf cfg.enable {
    services.mullvad-vpn.enable = true;
    services.mullvad-vpn.package = pkgs.mullvad-vpn;
  };
}

