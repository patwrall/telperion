{ lib
, ...
}: {
  services.xserver.displayManager = {
    lightdm.enable = lib.mkForce false;
  };
}
