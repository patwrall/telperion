{ config
, lib
, pkgs
, osConfig ? { }
, ...
}:
let
  inherit (lib)
    mkIf
    mkDefault
    types
    ;
  inherit (lib.telperion) mkOpt boolToNum nested-default-attrs;

  cfg = config.telperion.theme.gtk;
in
{
  options.telperion.theme.gtk = {
    enable = lib.mkEnableOption "customizing GTK and apply themes";
    usePortal = lib.mkEnableOption "using the GTK Portal";

    cursor = {
      name = mkOpt types.str "catppuccin-macchiato-blue-cursors" "The name of the cursor theme to apply.";
      package = mkOpt types.package
        (
          if pkgs.stdenv.hostPlatform.isLinux then
            pkgs.catppuccin-cursors.macchiatoBlue
          else
            pkgs.emptyDirectory
        ) "The package to use for the cursor theme.";
      size = mkOpt types.int 32 "The size of the cursor.";
    };

    icon = {
      name = mkOpt types.str "Papirus-Dark" "The name of the icon theme to apply.";
      package = mkOpt types.package
        (pkgs.catppuccin-papirus-folders.override {
          accent = "blue";
          flavor = "macchiato";
        }) "The package to use for the icon theme.";
    };
  };


  config = mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isLinux) {
    home = {
      packages = with pkgs; [
        # NOTE: required explicitly with noXlibs and home-manager
        dconf
        glib # gsettings
        gtk3.out # for gtk-launch
        libappindicator-gtk3
      ];

      pointerCursor = mkDefault {
        name = mkDefault cfg.cursor.name;
        package = mkDefault cfg.cursor.package;
        size = mkDefault cfg.cursor.size;
        gtk.enable = true;
        x11.enable = true;
      };

      sessionVariables = {
        GTK_USE_PORTAL = "${toString (boolToNum cfg.usePortal)}";
        CURSOR_THEME = mkDefault cfg.cursor.name;
      };
    };

    dbus.packages = [ pkgs.dconf ];



    gtk = {
      enable = true;

      font = {
        name = mkDefault (osConfig.telperion.system.fonts.default or "JetBrains Mono Nerd Font");
        size = mkDefault (osConfig.telperion.system.fonts.size or 12);
      };

      iconTheme = {
        name = mkDefault cfg.icon.name;
        package = mkDefault cfg.icon.package;
      };
    };

    xdg = {
      systemDirs.data =
        let
          schema = pkgs.gsettings-desktop-schemas;
        in
        [ "${schema}/share/gsettings-schemas/${schema.name}" ];
    };
  };
}
