{ config
, pkgs
, lib
, ...
}: {
  programs.fish = {
    enable = true;
  };

  home.packages = with pkgs; [
    fishPlugins.fzf-fish
    fishPlugins.colored-man-pages
  ];
}
