{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.stremio;

in
{
  options.telperion.programs.graphical.apps.stremio = {
    enable = mkEnableOption "stremio";
  };

  config = mkIf cfg.enable {
    # The old `stremio` (Qt5 shell) was removed from nixpkgs for depending on
    # an outdated, vulnerable qt5 webengine; stremio-linux-shell replaces it.
    home.packages = with pkgs; [
      stremio-linux-shell
    ];
  };
}
