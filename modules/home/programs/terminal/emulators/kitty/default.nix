{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.emulators.kitty;
in
{
  options.telperion.programs.terminal.emulators.kitty = {
    enable = lib.mkEnableOption "kitty";
  };

  config = mkIf cfg.enable {
    programs.kitty = {
      enable = true;

      font = {
        name = "JetBrains Mono Nerd Font";
        size = 12;
      };

      settings = {
        shell = "fish";
        scrollback_lines = 10000;
        cursor_shape = "beam";
        cursor_beam_thickness = "1.5";
        window_padding_width = 25;
        background_opacity = "0.78";
        enable_audio_bell = "no";
        bold_font = "auto";
        italic_font = "auto";
        bold_italic_font = "auto";
      };

      keybindings = {
        "page_up" = "scroll_page_up";
        "page_down" = "scroll_page_down";
        "ctrl+shift+f" = "show_scrollback";
      };

      # Ambxst writes dynamic theme colors here and sends SIGUSR1 to reload
      extraConfig = ''
        include ${config.home.homeDirectory}/.cache/ambxst/kitty.conf
      '';
    };
  };
}
