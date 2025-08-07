{ lib
, host ? null
, ...
}:
let
  inherit (lib) types;
  inherit (lib.telperion) mkOpt;
in
{
  options.telperion.host = {
    name = mkOpt (types.nullOr types.str) host "The host name.";
  };
}
