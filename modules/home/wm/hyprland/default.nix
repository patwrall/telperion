{ pkgs
, ...
}:
{
  imports = [
    ./hyprland.nix
    ./keybinds.nix
  ];

  home.packages = with pkgs; [
    hyprland
    kitty
    wl-clipboard
  ];
}
