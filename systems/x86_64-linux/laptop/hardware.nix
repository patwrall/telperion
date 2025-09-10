{ pkgs
, lib
, modulesPath
, ...
}:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    blacklistedKernelModules = [ "eeepc_wmi" ];

    kernelPackages = pkgs.linuxPackages_latest;
    kernel.sysctl."kernel.sysrq" = 1;

    initrd = {
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "ehci_pci"
        "ahci"
        "usb_storage"
        "usbhid"
        "sd_mod"
        "sr_mod"
      ];
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
  };

  telperion.hardware = {
    audio = enabled;

    bluetooth = {
      enable = true;
      autoConnect = true;
    };
    cpu.intel = enabled;

    fingerprint = enabled;

    opengl = enabled;

    storage = {
      enable = true;
      ssdEnable = true;
    };

    tpm = enabled;
  };
}

