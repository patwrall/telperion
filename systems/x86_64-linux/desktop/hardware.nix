{ config
, pkgs
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
    # LTS, not _latest: tried first for Xid 8/31/109 GPU faults (onset matched
    # _latest 7.2.5 -> 7.2.6), but faults recurred on 6.18; see nvidia.package.
    kernelPackages = pkgs.linuxPackages;
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
    # 615 branch: 595.99.02 threw Xid 31/109 MMU faults under Dragonwilds
    # (UE5/vkd3d) on both 7.2.x and 6.18 LTS kernels.
    nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;
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

