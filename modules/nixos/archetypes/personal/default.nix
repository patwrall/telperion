{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.archetypes.personal;
in
{
  options.telperion.archetypes.personal = {
    enable = lib.mkEnableOption "the personal archetype";
  };

  config = mkIf cfg.enable {
    telperion = {
      services = {
        tailscale = enabled;
      };

      suites = {
        common = enabled;
      };
    };
  };
}
