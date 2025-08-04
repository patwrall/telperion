{ host
, ...
}:
let
  inherit (import ../../hosts/${host}/variables.nix) keyboardLayout keyboardVariant;
in
{
  services.xserver = {
    enable = true;
    xkb = {
      layout = keyboardLayout;
      variant = keyboardVariant;
    };
  };

  hardware.graphics = {
    enable = true;
  };
}
