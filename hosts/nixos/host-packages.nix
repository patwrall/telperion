{ pkgs
, ...
}: {
  environment.systemPackages = with pkgs; [
    fish
    w3m
  ];
}
