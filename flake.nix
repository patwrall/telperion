{
  description = "My NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";

    hyprland.url = "github:hyprwm/Hyprland";
    hyprland.inputs.nixpkgs.follows = "nixpkgs";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs
    , home-manager
    , flake-parts
    , ...
    } @ inputs:
    let
      host = "nixos";
      profile = "vm";
      username = "pat";
    in
    flake-parts.lib.mkFlake { inherit inputs; }
      {
        imports = [
          # ./flake/packages.nix
        ];

        systems = [ "x86_64-linux" "aarch64-linux" ];

        flake = {
          nixosConfigurations = {
            vm = nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs = {
                inherit inputs;
                inherit username;
                inherit host;
                inherit profile;
              };
              modules = [
                ./profiles/vm
              ];
            };
          };
        };
      };
}
