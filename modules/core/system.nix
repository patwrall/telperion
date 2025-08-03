{ host
, ...
}:
let
  inherit (../../hosts/${host}/variables.nix) consoleKeyMap;
in
{
  nix = {
    settings = {
      download-buffer-size = 250000000;
      auto-optimise-store = true;

      experimental-features = [
        "nix-command"
        "flakes"
      ];

      substituters = [
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "hyprland.cachix.org-1:a7pgxzmz7+chwvl3/pzj6jibmioijm7ypfp8pwtkugc="
      ];
      require-sigs = true;
    };
  };
  console.keymap = consoleKeyMap;
  system.stateVersion = "25.05";
}
