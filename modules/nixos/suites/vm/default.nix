{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.vm;
in
{
  options.telperion.suites.vm = {
    enable = lib.mkEnableOption "common vm configuration";
  };

  config = mkIf cfg.enable {
    telperion = {
      services = {
        spice-vdagentd = lib.mkDefault enabled;
        spice-webdav = lib.mkDefault enabled;
      };
    };
  };
}
