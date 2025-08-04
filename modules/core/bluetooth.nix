{ host
, pkgs
, lib
, ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix) bluetoothEnable;
in
{
  services = lib.mkIf bluetoothEnable {
    blueman.enable = true;
    pipewire.wireplumber.enable = true;
  };

  hardware = lib.mkIf bluetoothEnable {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  environment.systemPackages = lib.mkIf bluetoothEnable (with pkgs; [
    bluez-tools
  ]);
}
