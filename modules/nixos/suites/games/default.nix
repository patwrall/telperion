{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.games;
in
{
  options.telperion.suites.games = {
    enable = lib.mkEnableOption "common games configuration";
  };

  config = lib.mkIf cfg.enable {
    telperion = {
      programs = {
        graphical = {
          addons = {
            gamemode = mkDefault enabled;
            gamescope = mkDefault enabled;
            # mangohud = mkDefault enabled;
          };

          apps = {
            steam = mkDefault enabled;
            hytale-launcher = mkDefault enabled;
          };
        };
      };

      services.flatpak.extraPackages = [
        # Sober for Roblox
        {
          appId = "org.vinegarhq.Sober";
          origin = "flathub";
        }
      ];
    };
  };
}
