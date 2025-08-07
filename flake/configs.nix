{ inputs
, self
, lib
, ...
}:
let
  inherit (self.lib.file) scanSystems filterNixOSSystems;

  systemsPath = ../systems;
  allSystems = scanSystems systemsPath;
in
{
  flake = {
    nixosConfigurations = lib.mapAttrs'
      (
        name:
        { system, hostname, ... }:
        {
          name = hostname;
          value = self.lib.system.mkSystem {
            inherit inputs system hostname;
            username = "pat";
          };
        }
      )
      (filterNixOSSystems allSystems);
  };
}
