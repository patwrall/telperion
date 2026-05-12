{ inputs
, config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.telperion.programs.graphical.apps.spicetify;

  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.telperion.programs.graphical.apps.spicetify = {
    enable = mkEnableOption "Spicetify";
  };

  config = mkIf cfg.enable {
    programs.spicetify = {
      enable = true;
      theme = spicePkgs.themes.defaultDynamic;
      enabledExtensions = with spicePkgs.extensions; [
        shuffle
        hidePodcasts
      ];
      enabledCustomApps = with spicePkgs.apps; [
        betterLibrary
        lyricsPlus
      ];
    };
  };
}
