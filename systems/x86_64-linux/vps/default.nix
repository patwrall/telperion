{ lib
, ...
}:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [
    ./disks.nix
    ./hardware.nix
    ./hermes-admin.nix
    ./hermes-x.nix
    ./hermes.nix
    ./network.nix
  ];

  telperion = {
    services.openssh = enabled;

    user = {
      extraGroups = [ "hermes" ];
      extraOptions.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOj3o8Xfni1CRwVscqcCdmSz7AJxC8rouXx7+gLPRHV9 GitHub: patwrall"
      ];
    };
  };

  # OVH VPS images boot legacy BIOS; this also boots if the VM is switched to
  # UEFI. disko adds every disk with an EF02 partition to grub.devices.
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    configurationLimit = 5;
  };

  # Headless server: mkSystem turns the ambxst desktop shell on by default.
  programs.ambxst.enable = false;

  # The user module sets zsh as the login shell.
  programs.zsh.enable = true;

  # SSH only over the tailnet (tailscale0 is trusted); OVH's KVM console is the fallback.
  services.openssh.openFirewall = lib.mkForce false;

  # SSH is key-only, so let wheel deploy with `nixos-rebuild --target-host --sudo`.
  security.sudo.wheelNeedsPassword = false;

  # Bootstrap secrets (Hermes env, Tailscale auth key), copied in at install
  # with `nixos-anywhere --extra-files`. Kept out of the repo and the store.
  systemd.tmpfiles.rules = [ "d /var/lib/secrets 0700 root root -" ];

  zramSwap.enable = true;

  system.stateVersion = "26.11";
}
