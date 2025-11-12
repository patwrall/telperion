{ inputs
}:
let
  inherit (inputs.nixpkgs.lib) filterAttrs mapAttrs';
in
{
  mkExtendedLib = flake: nixpkgs: nixpkgs.lib.extend flake.lib.overlay;

  mkNixpkgsConfig = flake: {
    overlays = builtins.attrValues flake.overlays;
    config = {
      allowAliases = false;
      allowUnfree = true;
      permittedInsecurePackages = [
        "gradle-7.6.6"
        # NOTE: citrix
        "libxml2-2.13.8"
        "libsoup-2.74.3"
        # NOTE: needed by emulationstation
        "freeimage-3.18.0-unstable-2024-04-18"
      ];
    };
  };

  mkHomeConfigs =
    { flake
    , system
    , hostname
    ,
    }:
    let
      inherit (flake.lib.file) scanHomes;
      homesPath = ../../homes;
      allHomes = scanHomes homesPath;
    in
    filterAttrs
      (
        _name: homeConfig: homeConfig.system == system && homeConfig.hostname == hostname
      )
      allHomes;

  mkHomeManagerConfig =
    { extendedLib
    , inputs
    , system
    , matchingHomes
    , isNixOS ? true
    ,
    }:
    if matchingHomes != { } then
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {
            inherit inputs system;
            inherit (inputs) self;
            lib = extendedLib;
            flake-parts-lib = inputs.flake-parts.lib;
          };
          sharedModules = [
            { _module.args.lib = extendedLib; }
          ]
          ++ (
            if isNixOS then
              [
                inputs.home-manager.flakeModules.home-manager
              ]
            else
              [ ]
          )
          ++ [
            inputs.nix-index-database.homeModules.nix-index
            inputs.sops-nix.homeManagerModules.sops
            inputs.opnix.homeManagerModules.default
            inputs.caelestia-shell.homeManagerModules.default
            inputs.spicetify-nix.homeManagerModules.spicetify
            inputs.zen-browser.homeModules.twilight
          ]
          ++ (extendedLib.importModulesRecursive ../../modules/home);
          users = mapAttrs'
            (_name: homeConfig: {
              name = homeConfig.username;
              value = {
                imports = [ homeConfig.path ];
                home = {
                  inherit (homeConfig) username;
                  homeDirectory = inputs.nixpkgs.lib.mkDefault (
                    if isNixOS then "/home/${homeConfig.username}" else "/Users/${homeConfig.username}"
                  );
                };
              }
              // (
                if isNixOS then
                  {
                    _module.args.username = homeConfig.username;
                  }
                else
                  { }
              );
            })
            matchingHomes;
        };
      }
    else
      { };

  mkSpecialArgs =
    { inputs
    , hostname
    , username
    , extendedLib
    ,
    }:
    {
      inherit inputs hostname username;
      inherit (inputs) self;
      lib = extendedLib;
      flake-parts-lib = inputs.flake-parts.lib;
      format = "system";
      host = hostname;
    };
}
