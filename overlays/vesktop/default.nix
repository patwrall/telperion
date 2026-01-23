{ inputs, ... }:
_final: prev: {
  inherit (inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system}) vesktop;
}
