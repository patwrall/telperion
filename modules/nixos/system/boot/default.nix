{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) default-attrs;

  cfg = config.telperion.system.boot;
in
{
  options.telperion.system.boot = {
    enable = lib.mkEnableOption "booting";
    secureBoot = lib.mkEnableOption "secure boot";
    silentBoot = lib.mkEnableOption "silent boot";
  };

  config = mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [
        efibootmgr
        efitools
        efivar
      ]
      ++ lib.optionals cfg.secureBoot [ sbctl ];

    boot = {
      initrd.systemd.network.wait-online.enable = false;

      kernel.sysctl = {
        "vm.swappiness" = 10;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_ratio" = 15;
        "vm.dirty_background_ratio" = 5;
      };

      kernelParams =
        lib.optionals cfg.silentBoot [
          # tell the kernel to not be verbose
          "quiet"

          # kernel log message level
          "loglevel=3" # 1: system is unusable | 3: error condition | 7: very verbose

          # udev log message level
          "udev.log_level=3"

          # lower the udev log level to show only errors or worse
          "rd.udev.log_level=3"

          # disable systemd status messages
          # rd prefix means systemd-udev will be used instead of initrd
          "systemd.show_status=auto"
          "rd.systemd.show_status=auto"

          # disable the cursor in vt to get a black screen during intermissions
          "vt.global_cursor_default=0"
        ];

      lanzaboote = mkIf cfg.secureBoot {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };

      loader = {
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint = "/boot";
        };

        generationsDir.copyKernels = true;

        systemd-boot = {
          enable = !cfg.secureBoot;
          configurationLimit = 20;
          editor = false;
        };

        timeout = 1;
      };


      tmp = default-attrs {
        useTmpfs = true;
        cleanOnBoot = true;
        tmpfsSize = "50%";
      };
    };

    services.fwupd = {
      enable = true;
      daemonSettings.EspLocation = config.boot.loader.efi.efiSysMountPoint;
    };
  };
}
