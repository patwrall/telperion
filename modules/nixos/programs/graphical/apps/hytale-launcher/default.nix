{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.graphical.apps.steam;
in
{
  options.telperion.programs.graphical.apps.hytale-launcher = {
    enable = lib.mkEnableOption "Hytale Launcher support";
  };

  config = mkIf cfg.enable {
    environment = {
      systemPackages = with pkgs; [ telperion.hytale-launcher ];
    };
  };
}
