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

          tools = {
            atuin = mkDefault enabled;
            bat = mkDefault enabled;
            btop = mkDefault enabled;
            carapace = mkDefault enabled;
            comma = mkDefault enabled;
            dircolors = mkDefault enabled;
            direnv = mkDefault enabled;
            eza = mkDefault enabled;
            fastfetch = mkDefault enabled;
            fzf = mkDefault enabled;
            jq = mkDefault enabled;
            navi = mkDefault enabled;
            nix-search-tv = mkDefault enabled;
            nh = mkDefault enabled;
            popcorn-cli = mkDefault enabled;
            ripgrep = mkDefault enabled;
            starship = mkDefault enabled;
            television = mkDefault enabled;
            yazi = mkDefault enabled;
            zellij = mkDefault enabled;
            zoxide = mkDefault enabled;
          };
        };
      };

      services = {
        udiskie.enable = mkDefault pkgs.stdenv.hostPlatform.isLinux;
        syncthing.enable = mkDefault pkgs.stdenv.hostPlatform.isLinux;
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
