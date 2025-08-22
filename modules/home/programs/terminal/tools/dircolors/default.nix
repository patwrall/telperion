{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.dircolors;
in
{
  options.telperion.programs.terminal.tools.dircolors = {
    enable = lib.mkEnableOption "dircolors";
  };

  config = mkIf cfg.enable {
    programs.dircolors = {
      enable = true;
    };
  };
}
