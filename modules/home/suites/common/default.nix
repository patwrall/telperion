{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.common;
in
{
  options.telperion.suites.common = {
    enable = lib.mkEnableOption "common configuration";
  };

  config = mkIf cfg.enable {
    home = {
      file = {
        ".hushlogin".text = "";
      };

      sessionVariables = {
        LESSHISTFILE = "${config.xdg.cacheHome}/less.history";
        WGETRC = "${config.xdg.configHome}/wgetrc";
      };

      shellAliases = {
        ndu = "nix-du -s=200MB | dot -Tsvg > store.svg";
      };
    };

    home.packages = with pkgs; [
      ncdu
      tree
      wikiman
      nix-du
      graphviz
    ];

    telperion = {
      programs = {
        terminal = {
          emulators = {
            foot = enabled;
          };

          shell = {
            fish = enabled;
          };
        };
      };
    };

    programs = {
      # FIXME: breaks zsh aliases
      # pay-respects = mkDefault enabled;
      readline = {
        enable = mkDefault true;

        extraConfig = ''
          set completion-ignore-case on
        '';
      };
    };

    xdg.configFile.wgetrc.text = "";
  };
}
