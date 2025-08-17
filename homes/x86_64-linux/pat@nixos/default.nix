{ config
, lib
, ...
}:
let
  inherit (lib) getExe;
  inherit (lib.telperion) enabled;
in
{
  telperion = {
    user = {
      enable = true;
      name = "pat";
    };

    system = {
      xdg = enabled;
    };
  };
}
