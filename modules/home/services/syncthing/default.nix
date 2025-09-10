{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.services.syncthing;
in
{
  options.telperion.services.syncthing = {
    enable = mkEnableOption "syncthing";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;

      tray.enable = pkgs.stdenv.hostPlatform.isLinux;
    };
  };
}
