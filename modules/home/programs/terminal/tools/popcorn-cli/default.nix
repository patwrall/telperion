{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.programs.terminal.tools.popcorn-cli;
in
{
  options.telperion.programs.terminal.tools.popcorn-cli = {
    enable = mkEnableOption "popcorn-cli";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.telperion.popcorn-cli ];
  };
}

