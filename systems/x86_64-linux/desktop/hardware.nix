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

    kernelModules = [ "uinput" ];
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
    cpu.amd = enabled;

    gpu.nvidia = {
      enable = true;
      enableCudaSupport = true;
      enableNvtop = true;
    };

    opengl = enabled;

    storage = {
      enable = true;
      ssdEnable = true;
    };

    tpm = enabled;
  };
}

