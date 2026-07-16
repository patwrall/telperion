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

  # nixpkgs' current spicetify-cli (2.44.0) no longer ships a prebuilt
  # jsHelper/spicetifyWrapper.js -- upstream moved it to a TS source that needs
  # a JS-bundler build step nixpkgs' buildGoModule doesn't run. Pull the last
  # release that still shipped the prebuilt file to restore it.
  spicetifyWrapperSrc = pkgs.fetchzip {
    url = "https://github.com/spicetify/cli/archive/refs/tags/v2.43.2.tar.gz";
    hash = "sha256-77OZVDtybkYI5R3tZ7q2cLJ+Ixn8WB4CP4qP6Yp535g=";
  };
in
{
  options.telperion.programs.graphical.apps.spicetify = {
    enable = mkEnableOption "Spicetify";

    fixedPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = ''
        spicetify-nix's spicedSpotify with Apps/xpui/helper/spicetifyWrapper.js
        restored. spicetify-cli 2.44.0 (current nixpkgs pin) never builds that
        file, but still leaves the <script src='helper/spicetifyWrapper.js'>
        reference in index.html, so Spotify never gets a working `Spicetify`
        global and every theme/extension throws `ReferenceError: Spicetify is
        not defined` on load, leaving the window blank. Use this instead of
        config.programs.spicetify.spicedSpotify wherever Spotify is actually
        launched.
      '';
    };
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

    telperion.programs.graphical.apps.spicetify.fixedPackage =
      config.programs.spicetify.spicedSpotify.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mkdir -p "$out/share/spotify/Apps/xpui/helper"
          cp ${spicetifyWrapperSrc}/jsHelper/spicetifyWrapper.js \
            "$out/share/spotify/Apps/xpui/helper/spicetifyWrapper.js"
        '';
      });
  };
}
