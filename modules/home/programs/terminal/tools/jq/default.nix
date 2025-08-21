{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.jq;
in
{
  options.telperion.programs.terminal.tools.jq = {
    enable = lib.mkEnableOption "jq";
  };

  config = mkIf cfg.enable {
    programs.jq = {
      enable = true;
      package = pkgs.jq;
    };
  };
}

