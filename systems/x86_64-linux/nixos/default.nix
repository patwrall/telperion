{ lib, ... }:
let
  inherit (lib.telperion) enabled;
in
{
  imports = [ ./hardware.nix ];

}
