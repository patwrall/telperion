{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.television;
in
{
  options.telperion.programs.terminal.tools.television = {
    enable = lib.mkEnableOption "television";
  };

  config = mkIf cfg.enable {
    programs.television = {
      enable = true;

      settings = {
        ui = {
          use_nerd_font_icons = true;
        };
      };
    };
  };
}
