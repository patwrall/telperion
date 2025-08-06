{ pkgs
, ...
}:
{
  imports = [
    ./hyprland.nix
  ];

  home.packages = with pkgs; [
    hyprland
    foot
    wl-clipboard
  ];
}
