{ config
, lib
, pkgs
, username ? null
, ...
}:
let
  inherit (lib)
    types
    mkIf
    mkDefault
    mkMerge
    getExe
    getExe'
    ;
  inherit (lib.telperion) mkOpt enabled;

  cfg = config.telperion.user;

  home-directory =
    if cfg.name == null then
      null
    else if pkgs.stdenv.hostPlatform.isDarwin then
      "/Users/${cfg.name}"
    else
      "/home/${cfg.name}";
in
{
  options.telperion.user = {
    enable = mkOpt types.bool false "Whether to configure the user account.";
    email = mkOpt types.str "patrickwrall@gmail.com" "The email of the user.";
    fullName = mkOpt types.str "Patrick Rall" "The full name of the user.";
    home = mkOpt (types.nullOr types.str) home-directory "The user's home directory.";
    name = mkOpt (types.nullOr types.str) username "The user account.";
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.name != null;
          message = "telperion.user.name must be set";
        }
        {
          assertion = cfg.home != null;
          message = "telperion.user.home must be set";
        }
      ];

      home = {
        file = {
          "Desktop/.keep".text = "";
          "Documents/.keep".text = "";
          "Downloads/.keep".text = "";
          "Music/.keep".text = "";
          "Pictures/Wallpapers" = {
            source = pkgs.telperion.wallpapers;
            recursive = true;
          };
          "Projects/.keep".text = "";
          "Videos/.keep".text = "";
        };

        homeDirectory = mkIf (cfg.home != null) (mkDefault cfg.home);

        shellAliases = {
          # Navigation shortcuts
          home = "cd ~";
          dots = "cd $DOTS_DIR";
          "v" = "nvim";
          "vi" = "nvim";
          "vi ." = "nvim";
          ".." = "cd ..";
          "..." = "cd ../..";
          "...." = "cd ../../..";
          "....." = "cd ../../../..";
          "......" = "cd ../../../../..";
        };

        username = mkDefault cfg.name;
      };

      programs.home-manager = enabled;
    }
  ]);
}
