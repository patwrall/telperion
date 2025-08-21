{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    ;

  cfg = config.telperion.theme.qt;
in
{
  options.telperion.theme.qt = {
    enable = lib.mkEnableOption "customizing qt and apply themes";
  };

  config = mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    home = {
      packages = with pkgs; [
        qt6.qtwayland
      ];

      sessionVariables = {
        # scaling - 1 means no scaling
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        # use wayland as the default backend, fallback to xcb if wayland is not available
        QT_QPA_PLATFORM = "wayland;xcb";
        # disable window decorations everywhere
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        # remain backwards compatible with qt5
        DISABLE_QT5_COMPAT = "0";
      };
    };

    qt = {
      enable = true;

      platformTheme = {
        name = mkDefault "qtct";
      };

      style = mkDefault { name = "qt6ct-style"; };
    };
  };
}
