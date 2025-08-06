{ config
, pkgs
, lib
, ...
}: {
  programs.fish = {
    enable = true;

    shellAliases = import ./aliases.nix;

    functions = import ./functions.nix;

    shellInit = ''
      set -g fish_greeting

      fish_vi_key_bindings
    '';

    interactiveShellInit = ''
    '';
  };

  home.packages = with pkgs; [
    fishPlugins.fzf-fish
    fishPlugins.colored-man-pages
  ];
}
