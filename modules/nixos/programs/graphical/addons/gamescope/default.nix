{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.telperion.programs.graphical.addons.gamescope;
in
{
  options.telperion.programs.graphical.addons.gamescope = {
    enable = lib.mkEnableOption "gamescope";
  };

  config = lib.mkIf cfg.enable {
    programs = {
      gamescope = {
        enable = true;
        package = pkgs.gamescope;

        capSysNice = true;
        args = [
          "--rt"
          "--expose-wayland"
        ];
      };
      steam.gamescopeSession.enable = true;
    };
  };
}
