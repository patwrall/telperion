{ modulesPath
, ...
}:
{
  # OVH VPSes are KVM guests with a virtio-scsi disk. The profile adds the
  # virtio drivers; sd_mod is already in the default initrd module set.
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
}
