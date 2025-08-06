{ pkgs
, ...
}:
{
  home.packages = with pkgs; [
    fastfetch
    macchina

    yazi

    zip
    xz
    unzip
    p7zip

    eza
    fzf
  ];
}
