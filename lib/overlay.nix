{
  inputs,
}:
_final: _prev:
let
  telperionLib = import ./default.nix { inherit inputs; };
  base64Lib = import ./base64 { inherit inputs; };
  fileLib = import ./file {
    inherit inputs;
    self = ../.;
  };
  moduleLib = import ./module { inherit inputs; };
  systemLib = import ./system { inherit inputs; };
in
{
  telperion = moduleLib;

  file = fileLib;
  system = systemLib;
  base64 = base64Lib;

  inherit (fileLib)
    getFile
    getNixFiles
    importFiles
    importDir
    importDirPlain
    importSubdirs
    importModulesRecursive
    mergeAttrs
    ;

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
