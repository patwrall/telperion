{ inputs
, lib
, ...
}:
let
  overlaysPath = ../overlays;
  dynamicOverlaysSet =
    if builtins.pathExists overlaysPath then
      let
        overlayDirs = builtins.attrNames (builtins.readDir overlaysPath);
      in
      lib.genAttrs overlayDirs (
        name:
        let
          overlayPath = overlaysPath + "/${name}";
          overlayFn = import overlayPath;
        in
        if lib.isFunction overlayFn then overlayFn { inherit inputs; } else overlayFn
      )
    else
      { };

  telperionPackagesOverlay =
    final: prev:
    let
      directory = ../packages;
      packageFunctions = prev.lib.filesystem.packagesFromDirectoryRecursive {
        inherit directory;
        callPackage = file: _args: import file;
      };
    in
    {
      telperion = prev.lib.fix (
        self:
        prev.lib.mapAttrs
          (
            _name: packageData: final.callPackage (packageData.default or packageData) (self // { inherit inputs; })
          )
          packageFunctions
      );
    };

  allOverlays = (lib.attrValues dynamicOverlaysSet) ++ [ telperionPackagesOverlay ];

in
{
  flake = {
    overlays = dynamicOverlaysSet // {
      default = telperionPackagesOverlay;
      telperion = telperionPackagesOverlay;
    };

    perSystem =
      { config, pkgs, ... }:
      {
        pkgs = pkgs.extend (lib.composeManyExtensions allOverlays);

        packages = config.pkgs.telperion;
      };
  };
}
