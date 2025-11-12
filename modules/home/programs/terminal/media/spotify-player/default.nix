{ config
, lib
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.programs.terminal.media.spotify-player;
in
{
  options.telperion.programs.terminal.media.spotify-player = {
    enable = mkEnableOption "spotify-player";
  };

  config = mkIf cfg.enable {
    programs.spotify-player = {
      enable = true;

      settings = { };
    };
  };
}
