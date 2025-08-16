{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.archetypes.vm;
in
{
  options.telperion.archetypes.vm = {
    enable = lib.mkEnableOption "the vm archetype";
  };

  config = mkIf cfg.enable {
    telperion = {
      suites = {
        common = enabled;
        desktop = enabled;
        development = enabled;
        vm = enabled;
      };
    };
  };
}
