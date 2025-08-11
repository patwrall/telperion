{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.bandwhich;
in
{
  options.telperion.programs.terminal.tools.bandwhich = {
    enable = lib.mkEnableOption "bandwhich";
  };

  config = mkIf cfg.enable {
    programs.bandwhich = {
      enable = true;
    };
  };
}
