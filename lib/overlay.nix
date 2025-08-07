{ inputs
}:
_final: _prev:
let
  telperionLib = import ./default.nix { inherit inputs; };
in
{
  telperion = telperionLib.flake.lib.module;

  inherit (telperionLib.flake.lib)
    file
    system
    base64
    ;

  inherit (telperionLib.flake.lib.file) getFile importModulesRecursive;

  inherit (telperionLib.flake.lib.module)
    mkOpt
    mkOpt'
    mkBoolOpt
    mkBoolOpt'
    enabled
    disabled
    capitalize
    boolToNum
    default-attrs
    force-attrs
    nested-default-attrs
    nested-force-attrs
    decode
    ;

  # Add home-manager lib functions
  inherit (inputs.home-manager.lib) hm;
}
