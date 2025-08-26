{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.go;
in
{
  options.telperion.programs.terminal.tools.go = {
    enable = lib.mkEnableOption "Go support";
  };

  config = mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        go
        gopls
      ];

      sessionVariables = {
        GOPATH = "$HOME/go";
      };
    };
  };
}
