{ host
, ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix);
in
{
  imports = [
    ./fish
  ];
}
