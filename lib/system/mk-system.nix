{ inputs }:
{ system
, hostname
, username ? "pat"
, modules ? [ ]
, ...
}:
let
  flake = inputs.self or (throw "mkSystem requires 'inputs.self' to be passed");
  common = import ./common.nix { inherit inputs; };

  extendedLib = common.mkExtendedLib flake inputs.nixpkgs;
  matchingHomes = common.mkHomeConfigs {
    inherit
      flake
      system
      hostname
      ;
  };
  homeManagerConfig = common.mkHomeManagerConfig {
    inherit
      extendedLib
      inputs
      system
      matchingHomes
      ;
    isNixOS = true;
  };
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = common.mkSpecialArgs {
    inherit
      inputs
      hostname
      username
      extendedLib
      ;
  };

  modules = [
    { _module.args.lib = extendedLib; }

    # Configure nixpkgs with overlays
    {
      nixpkgs = {
        inherit system;
      }
      // common.mkNixpkgsConfig flake;
    }

    # Work around ambxst nixosModule bug: pkgs.system doesn't exist in module
    # context; use system from our closure instead.
    ({ lib, ... }: {
      imports = [ "${inputs.ambxst}/nix/modules" ];
      programs.ambxst.enable = lib.mkDefault true;
      programs.ambxst.package = lib.mkDefault inputs.ambxst.packages.${system}.default;
    })
    inputs.home-manager.nixosModules.home-manager
    inputs.lanzaboote.nixosModules.lanzaboote
    inputs.sops-nix.nixosModules.sops
    inputs.opnix.nixosModules.default
    inputs.disko.nixosModules.disko
    inputs.stylix.nixosModules.stylix
    inputs.nix-index-database.nixosModules.nix-index
    inputs.nix-flatpak.nixosModules.nix-flatpak

    # Auto-inject home configurations for this system+hostname
    homeManagerConfig

    # Import all nixos modules recursively
  ]
  ++ (extendedLib.importModulesRecursive ../../modules/nixos)
  ++ (extendedLib.importModulesRecursive ../../secrets)
  ++ [
    ../../systems/${system}/${hostname}
  ]
  ++ modules;
}
