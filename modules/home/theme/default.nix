{ config
, lib
, ...
}:
let
  inherit (lib) types;
  inherit (lib.telperion) mkOpt;
in
{
  options.telperion.theme = with types; {
    cursor = {
      name = mkOpt str "Bibata-Modern-Classic" "The name of the cursor theme to use.";
      size = mkOpt int 24 "The size of the cursor.";
    };
  };

  config = {
    # Default theme configuration
    telperion.theme = {
      cursor = {
        name = "Bibata-Modern-Classic";
        size = 24;
      };
    };
  };
}
