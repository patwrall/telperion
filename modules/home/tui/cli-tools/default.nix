{ pkgs
, ...
}:
{
  home.packages = with pkgs; [
    fastfetch
    macchina

    yazi

    eza
    fzf
  ];
}
