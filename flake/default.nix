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

  partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
    "checks"
    "formatter"
  ]
    (_: "dev");
}
