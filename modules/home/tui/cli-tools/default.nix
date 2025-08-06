{ pkgs
, ...
}:
{
  home.packages = with pkgs; [
    fastfetch

    yazi

    zip
    xz
    unzip
    p7zip

    ripgrep
    jq
    yq-go
    eza
    fzf
    bat
    zoxide
    wlr-randr
    nix-prefetch-github

    rustc
    cargo
    meson


    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    # _1password-cli

    btop

    strace
    ltrace
    lsof

    sysstat
    pciutils
    usbutils
  ];
}
