{ lib, ... }:
{
  options.telperion.hardware.cpu = {
    enable = lib.mkEnableOption "No-op used for setting up hierarchy";
  };
}
