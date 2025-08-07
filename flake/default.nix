{ inputs
, ...
}:
{
  imports = [
    ../lib
    ./configs.nix
    ./overlays.nix
    ./packages.nix
    inputs.flake-parts.flakeModules.partitions
  ];

  partitionedAttrs = inputs.nixpkgs.lib.genAttrs [
    "checks"
    "formatter"
  ]
    (_: "dev");
}
