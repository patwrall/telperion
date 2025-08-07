{ lib, ... }:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [ ./hardware.nix ];

  telperion = {

    system = {
      boot = enabled;
    };
  };

  system.stateVersion = "25.05";
}
