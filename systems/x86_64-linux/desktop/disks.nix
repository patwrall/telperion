{ disks ? [
    # 0: OS Drive - 1TB Samsung NVMe
    "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S6S1NS0W103926H"
    # 1: Fast Storage - 500GB Crucial NVMe
    "/dev/disk/by-id/nvme-gCT500P2SSD8_2038E4B0F889"
    # 2: Bulk Storage - 1TB Seagate HDD
    "/dev/disk/by-id/ata-ST1000DM003-1CH162_S1DB06CD"
    # 3: Backup/Misc - 500GB Seagate HDD
    "/dev/disk/by-id/ata-ST3500413AS_Z2AV08X1"
  ]
, ...
}:
let
  defaultBtrfsOpts = [
    "defaults"
    "compress=zstd:1"
    "ssd"
    "noatime"
    "nodiratime"
  ];
  defaultHddBtrfsOpts = builtins.filter (opt: opt != "ssd") defaultBtrfsOpts;
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

      # # Drive 1: 500GB NVMe for fast storage
      # nvme1 = {
      #   device = builtins.elemAt disks 1;
      #   type = "disk";
      #   content = {
      #     type = "gpt";
      #     partitions = {
      #       storage = {
      #         size = "100%";
      #         content = {
      #           type = "filesystem";
      #           format = "btrfs";
      #           mountpoint = "/fast-storage";
      #           mountOptions = defaultBtrfsOpts;
      #           extraArgs = [ "-LFastStorage" ];
      #         };
      #       };
      #     };
      #   };
      # };

      # Drive 2: 1TB HDD for bulk storage
      hdd0 = {
        device = builtins.elemAt disks 2;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            storage = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/bulk-storage";
                mountOptions = defaultHddBtrfsOpts;
                extraArgs = [ "-LBulkStorage" ];
              };
            };
          };
        };
      };

      # Drive 3: 500GB HDD for backups or misc storage
      hdd1 = {
        device = builtins.elemAt disks 3;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            storage = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/backup";
                mountOptions = defaultHddBtrfsOpts;
                extraArgs = [ "-LBackup" ];
              };
            };
          };
        };
      };
    };
  };
}
