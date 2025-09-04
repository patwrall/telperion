{ inputs
, ...
}:
{
  imports = [
    ../lib
    ./configs.nix
    ./home.nix
    ./overlays.nix
    ./packages.nix
    # ./templates.nix
    inputs.flake-parts.flakeModules.partitions
  ];

  partitions.dev = {
    module = ./dev;
    extraInputsFlake = ./dev;
  };

  partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
    "checks"
    "devShells"
    "formatter"
  ]
    (_: "dev");
}
