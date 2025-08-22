{ inputs }:
{ system
, hostname
, username ? "pat"
, modules ? [ ]
, ...
}:
let
  flake = inputs.self or (throw "mkHome requires 'inputs.self' to be passed");
  common = import ./common.nix { inherit inputs; };

  extendedLib = common.mkExtendedLib flake inputs.nixpkgs-unstable;
in
inputs.home-manager.lib.homeManagerConfiguration {
  pkgs = import inputs.nixpkgs-unstable {
    inherit system;
    inherit ((common.mkNixpkgsConfig flake)) config overlays;
  };

  extraSpecialArgs = {
    inherit
      inputs
      hostname
      username
      system
      ;
    inherit (flake) self;
    lib = extendedLib;
    flake-parts-lib = inputs.flake-parts.lib;
  };

  modules = [
    { _module.args.lib = extendedLib; }

    inputs.nix-index-database.homeModules.nix-index
    inputs.sops-nix.homeManagerModules.sops
    inputs.opnix.homeManagerModules.default

    # Import all home modules recursively
  ]
  ++ (extendedLib.importModulesRecursive ../../modules/home)
  ++ modules;
}
