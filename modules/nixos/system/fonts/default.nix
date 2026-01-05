{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mapAttrs;

  cfg = config.telperion.system.fonts;
in
{
  imports = [ (lib.getFile "modules/common/system/fonts/default.nix") ];

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      fontpreview
    ];

    fonts = {
      packages = cfg.fonts;
      enableDefaultPackages = true;

      fontconfig = {

        localConf = ''
          <fontconfig>
            <alias>
              <family>monospace</family>
              <prefer>
                <family>JetBrains Mono</family>
                <family>Monaspace Neon</family>
                <family>Cascadia Code</family>
              </prefer>
            </alias>

            <alias>
              <family>sans-serif</family>
              <prefer>
                <family>Lexend</family>
                <family>Inter</family>
              </prefer>
            </alias>

            <alias>
              <family>serif</family>
              <prefer>
                <family>Noto Serif</family>
              </prefer>
            </alias>
          </fontconfig>
        '';

        # allowType1 = true;
        # Defaults to true, but be explicit
        antialias = true;
        hinting.enable = true;

        subpixel.rgba = "rgb";

        defaultFonts =
          let
            common = [
              "MonaspaceNeon"
              "CascadiaCode"
              "Symbols Nerd Font"
              "Noto Color Emoji"
            ];
          in
          mapAttrs (_: fonts: fonts ++ common) {
            serif = [ "Noto Serif" ];
            sansSerif = [ "Lexend" ];
            emoji = [ "Noto Color Emoji" ];
            monospace = [
              "Source Code Pro Medium"
              "Source Han Mono"
              "JetBrains Mono"
            ];
          };
      };

      fontDir = {
        enable = true;
        decompressFonts = true;
      };
    };
  };
}
