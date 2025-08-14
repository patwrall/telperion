{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.telperion.theme;
in
{
  options.telperion.theme = {
    enable = lib.mkEnableOption "system-wide cursor theme";

    cursor = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Bibata-Modern-Classic";
        description = "The name of the cursor theme to apply.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.bibata-cursors;
        description = "The package providing the cursor theme.";
      };
      size = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "The size of the cursor.";
      };
    };
  };


  config = lib.mkIf cfg.enable {
    environment = {
      sessionVariables = {
        CURSOR_THEME = cfg.cursor.name;
        XCURSOR_THEME = cfg.cursor.name;
        XCURSOR_SIZE = toString cfg.cursor.size;
      };

      systemPackages = [ cfg.cursor.package ];
    };
  };
}
