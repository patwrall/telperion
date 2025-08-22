{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.programs.terminal.tools.direnv;
in
{
  options.telperion.programs.terminal.tools.direnv = {
    enable = lib.mkEnableOption "direnv";
  };

  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv = enabled;
      silent = true;
    };
  };
}
