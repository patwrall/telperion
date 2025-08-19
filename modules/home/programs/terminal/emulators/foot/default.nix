{ config
, pkgs
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.emulators.foot;
in
{
  options.telperion.programs.terminal.emulators.foot = {
    enable = lib.mkenableoption "foot";
  };


  config = mkIf cfg.enable {
    home.packages = with pkgs; [ libsixel ];

    home.foot = {
      enable = true;
      package = pkgs.foot;

      server.enable = false;

      settings = {
        main = {
          shell = "fish";
          title = "foot";
          font = "JetBrains Mono Nerd Font:size=12";
          letter-spacing = 0;
          dpi-aware = "no";
          pad = "25x25";
          bold-text-in-bright = "no";
          gamma-correct-blending = "no";
        };

        scrollback = {
          lines = 10000;
        };

        cursor = {
          style = "beam";
          beam-thickness = 1.5;
        };

        colors = {
          alpha = lib.mkDefault "0.78";
        };

        tweak = {
          font-monospace-warn = "no";
          sixel = "yes";
        };

        key-bindings = {
          scrollback-up-page = "Page_Up";
          scrollback-down-page = "Page_Down";
          search-start = "Control+Shift+f";
        };
      };
    };
  };
}
