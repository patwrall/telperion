{ lib
, ...
}:
{
  options.telperion.hardware.gpu = {
    enable = lib.mkEnableOption "No-op for setting up hierarchy";
  };
}
