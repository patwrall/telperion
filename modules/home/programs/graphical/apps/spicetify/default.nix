{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.programs.graphical.apps.spicetify;
in
{
  options.telperion.programs.graphical.apps.spicetify = {
    enable = mkEnableOption "Spicetify";
  };

  config = mkIf cfg.enable {
    programs.spicetify = {
      enable = true;

      theme = {
        name = "caelestia";

        src =
          pkgs.fetchFromGitHub
            {
              owner = "caelestia-dots";
              repo = "caelestia";
              rev = "main";
              hash = "sha256-hlllZYG8MChQb7cUPQUJxrC0Uc3z1RVBj7BgWt2OJ8E=";
            }
          + "/spicetify/Themes/caelestia";

        injectCss = true;
        injectThemeJs = true;
        replaceColors = true;
        homeConfig = true;
        overwriteAssets = false;

        additionalCss = '''';
      };
    };
  };
}
