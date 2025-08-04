{ pkgs
, ...
}: {
  environment.systemPackages = with pkgs; [
    curl
    fish
    git
    htop
    iputils
    ncdu
    vim
    w3m
    wget
  ];
}
