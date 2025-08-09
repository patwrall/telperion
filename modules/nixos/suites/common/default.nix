{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.common;
in
{
  imports = [ (lib.getFile "modules/common/suites/common/default.nix") ];

  config = mkIf cfg.enable {
    environment = {
      defaultPackages = lib.mkForce [ ];

      systemPackages = with pkgs; [
        dnsutils
        fortune
        isd
        lazyjournal
        lolcat
        lshw
        pciutils
        rsync
        util-linux
        wget
      ];
    };

    telperion = {
      hardware = {
        power = mkDefault enabled;
        fans = mkDefault enabled;
      };

      nix = mkDefault enabled;

      programs = {
        terminal = {
          tools = {
            bandwhich = mkDefault enabled;
            nix-ld = mkDefault enabled;
          };
        };
      };

      security = {
        clamav = mkDefault enabled;
        pam = mkDefault enabled;
        usbguard = mkDefault enabled;
      };

      services = {
        ddccontrol = mkDefault enabled;
        earlyoom = mkDefault enabled;
        logind = mkDefault enabled;
        logrotate = mkDefault enabled;
        oomd = mkDefault enabled;
        openssh = mkDefault enabled;
        printing = mkDefault enabled;
      };

      system = {
        fonts = mkDefault enabled;
        locale = mkDefault enabled;
        time = mkDefault enabled;
      };
    };

    programs.fish = {
      enable = true;
    };

    zramSwap.enable = true;
  };
}
