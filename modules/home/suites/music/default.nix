{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.music;
in
{
  options.telperion.suites.music = {
    enable = lib.mkEnableOption "common music configuration";
  };

  config = mkIf cfg.enable {
    telperion = {
      programs.terminal = {
        media = {};

        tools = {
          cava = lib.mkDefault enabled;
        };
      };
    };
  };
}
