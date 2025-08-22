{ config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.terminal.tools.starship;
in
{
  options.telperion.programs.terminal.tools.starship = {
    enable = mkEnableOption "Starship";
  };


  config = mkIf cfg.enable {
    programs.starship.enable = true;

    programs.starship.settings = lib.importTOML ./starship.toml;
  };
}
