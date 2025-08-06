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

    ripgrep
    jq
    yq-go
    eza
    fzf
    bat
    zoxide
    wev
    wlr-randr
    nix-prefetch-github

    rustc
    cargo
    gh
    meson

    mtr
    iperf3
    dnsutils
    ldns
    aria2
    socat
    nmap
    ipcalc

    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg
    # _1password-cli

    glow
    btop
    iotop
    iftop

    strace
    ltrace
    lsof

    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
  ];
}
