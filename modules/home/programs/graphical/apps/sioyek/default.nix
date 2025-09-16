{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.sioyek;

in
{
  options.telperion.programs.graphical.apps.sioyek = {
    enable = mkEnableOption "sioyek";
  };

  config = mkIf cfg.enable {
    programs.sioyek = {
      enable = true;

      bindings = { };

      config = {
        default_dark_mode = "1";
      };
    };
  };
}

