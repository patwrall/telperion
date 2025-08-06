{ config
, pkgs
, lib
, ...
}: {
  programs.fish = {
    enable = true;

    shellAliases = import ./aliases.nix;

    functions = import ./functions.nix { inherit pkgs lib; };

    shellInit = ''
      set -g fish_greeting
      
      set -g fish_color_command blue
      set -g fish_color_param cyan
      set -g fish_color_redirection yellow
      set -g fish_color_comment brblack
      set -g fish_color_error red
      set -g fish_color_escape magenta
      set -g fish_color_operator green
      set -g fish_color_quote yellow
      set -g fish_color_autosuggestion brblack
      set -g fish_color_valid_path --underline


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
