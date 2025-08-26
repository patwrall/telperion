{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.cava;
in
{
  options.telperion.programs.terminal.tools.cava = {
    enable = lib.mkEnableOption "cava";
  };

  config = mkIf cfg.enable {
    home.shellAliases = {
      cava = "TERM=st-256color cava";
    };

    programs.cava = {
      enable = true;
      package = if pkgs.stdenv.hostPlatform.isLinux then pkgs.cava else pkgs.emptyDirectory;
    };
  };
}
