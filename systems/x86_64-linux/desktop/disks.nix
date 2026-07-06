let
  disks = [
    # 0: OS Drive - 500GB Crucial NVMe
    "/dev/disk/by-id/nvme-CT500P2SSD8_2038E4B0F889"
    # 1: Extra/fast storage (games, etc.) - 1TB Samsung 970 EVO Plus NVMe
    "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S6S1NS0W103926H"
  ];
  defaultBtrfsOpts = [
    "defaults"
    "compress=zstd:1"
    "ssd"
    "noatime"
    "nodiratime"
  ];
in
{
  disko.devices = {
    disk = {
      nvme0 = {
        device = builtins.elemAt disks 0;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            efi = {
              priority = 1;
              name = "efi";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
                extraArgs = [ "-nEFI" ];
              };
            };
            linux = {
              size = "100%";
              name = "linux";
              content = {
                type = "btrfs";
                extraArgs = [ "-LLinux" ];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = defaultBtrfsOpts;
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = defaultBtrfsOpts;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = defaultBtrfsOpts ++ [ "nodatacow" ];
                  };
                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = defaultBtrfsOpts;
                  };
                };
              };
            };
            swap = {
              size = "4G";
              content = {
                type = "swap";
                discardPolicy = "both";
                randomEncryption = true;
                resumeDevice = true;
                extraArgs = [ "-Lswap" ];
              };
            };
          };
        };
      };

      # -----------------------------------------------------
      # -- Additional Storage Drives --
      # -----------------------------------------------------

      # Drive 1: 1TB Samsung NVMe for fast storage (games, etc.)
      nvme1 = {
        device = builtins.elemAt disks 1;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            storage = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/fast-storage";
                mountOptions = defaultBtrfsOpts;
                extraArgs = [ "-LFastStorage" ];
              };
            };
          };
        };
      };
    };
  };
}
