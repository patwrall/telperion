{ config
, lib
, pkgs
, options
, ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    types
    ;

  # Use direct mkOpt implementation to avoid circular dependency
  mkOpt =
    type: default: description:
    lib.mkOption { inherit type default description; };

  cfg = config.telperion.theme.stylix;
in
{ }
