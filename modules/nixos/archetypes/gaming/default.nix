{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.archetypes.gaming;
in
{
  options.telperion.archetypes.gaming = {
    enable = lib.mkEnableOption "the gaming archetype";
  };

  config = mkIf cfg.enable {
    telperion.suites = {
      common = enabled;
      desktop = enabled;
      games = enabled;
    };
  };
}
