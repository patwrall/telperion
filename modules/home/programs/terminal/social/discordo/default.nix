{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.programs.terminal.social.discordo;
in
{
  options.telperion.programs.terminal.social.discordo = {
    enable = mkEnableOption "Whether or not to enable discordo - terminal discord";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      discordo
    ];
  };
}
