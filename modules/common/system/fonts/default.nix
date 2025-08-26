{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) types mkIf;
  inherit (lib.telperion) mkOpt;

  cfg = config.telperion.system.fonts;
in
{
  options.telperion.system.fonts = with types; {
    enable = lib.mkEnableOption "managing fonts";
    fonts =
      with pkgs;
      mkOpt (listOf package) [
        # Desktop Fonts
        corefonts # MS fonts
        b612 # high legibility
        material-icons
        material-design-icons
        material-symbols
        work-sans
        comic-neue
        source-sans
        inter
        lexend

        # Emojis
        noto-fonts-color-emoji
        noto-fonts-monochrome-emoji


        # Nerd Fonts
        cascadia-code
        monaspace
        nerd-fonts.symbols-only
        nerd-fonts.jetbrains-mono
      ] "Custom font packages to install.";
    default = mkOpt types.str "JetBrains Mono" "Default font name";
    size = mkOpt types.int 13 "Default font size";
  };

  config = mkIf cfg.enable {
    environment.variables = {
      # Enable icons in tooling since we have nerdfonts.
      LOG_ICONS = "true";
      _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=on -Dswing.aatext=true -Dsun.java2d.xrender=true";
    };
  };
}
