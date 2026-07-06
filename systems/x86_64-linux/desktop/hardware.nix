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

    # NVMe / PCIe power-management workaround: this board (MS-7C56, Ryzen 3600X)
    # drops NVMe controllers off the bus under deep-idle / ASPM. Affects both
    # installed drives independently — platform-level, not drive-specific.
    kernelParams = [
      "nvme_core.default_ps_max_latency_us=0"
      "pcie_aspm=off"
      "pcie_port_pm=off"
    ];

    # For gpu profiling
    extraModprobeConfig = ''
      options nvidia "NVreg_RestrictProfilingToAdminUsers=0"
    '';

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

    logitech = enabled;

    opengl = enabled;

    storage = {
      enable = true;
      ssdEnable = true;
    };

    tpm = enabled;
  };
}

