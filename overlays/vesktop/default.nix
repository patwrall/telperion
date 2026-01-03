{ inputs, ... }:
final: prev: {
  vesktop = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system}.vesktop;
}
