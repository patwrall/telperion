{
  lib,
  ...
}:
let
  inherit (lib.telperion) enabled;
in
{
  telperion = {
    user = {
      enable = true;
      name = "pat";
    };

    dots = {
      end-4 = enabled;
    };

    programs = {
      graphical = {
        browsers = {
          zen-browser = enabled;
        };
      };
    };

    system = {
      xdg = enabled;
    };

    suites = {
      common = enabled;
    };
  };

  home.stateVersion = "25.05";
}
