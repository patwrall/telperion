{ host
, lib
, ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix) printEnable;
in
{
  services = lib.mkIf printEnable {
    printing = {
      enable = true;
      drivers = [ ];
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    ipp-usb.enable = true;
  };
}
