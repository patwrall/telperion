{ config
, pkgs
, ...
}:
{
  programs.foot = {
    enable = true;

    settings = {
      main = {
        font = "JetBrains Mono Nerd Font:size=12";
        letter-spacing = 0;
        dpi-aware = "no";
        pad = "25x25";
        bold-text-in-bright = "no";
      };

      scrollback = {
        lines = 10000;
      };

      cursor = {
        style = "beam";
        beam-thickness = 1.5;
      };

      colors = {
        alpha = 0.78;
        # You'd typically define foreground/background/cursor colors here too,
        # but they are not in your provided snippet.
        # foreground = "000000";
        # background = "FFFFFF";
      };

      "key-bindings" = {
        scrollback-up-page = "Page_Up";
        scrollback-down-page = "Page_Down";
        "search-start" = "Control+Shift+f";
      };

      "search-bindings" = {
        cancel = "Escape";
        "find-prev" = "Shift+F3";
        "find-next" = "F3 Control+G";
      };
    };
  };

  home.packages = with pkgs; [
    foot
  ];
}
