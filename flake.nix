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
      system = "x86_64-linux";
      host = "nixos";
      profile = "vm";
      username = "pat";
    in
    flake-parts.lib.mkFlake { inherit inputs; }
      {
        imports = [
          ./modules/flake/packages.nix
        ];
        nixosConfigurations = {
          vm = nixpkgs.lib.nixosSystem {
            inherit system;
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
}
