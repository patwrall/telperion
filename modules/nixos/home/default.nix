{ config
, lib
, options
, ...
}:
let
  inherit (lib) types mkAliasDefinitions;
  inherit (lib.telperion) mkOpt;
in
{

  options.telperion.home = with types; {
    configFile =
      mkOpt attrs { }
        "A set of files to be managed by home-manager's <option>xdg.configFile</option>.";
    extraOptions = mkOpt attrs { } "Options to pass directly to home-manager.";
    file = mkOpt attrs { } "A set of files to be managed by home-manager's <option>home.file</option>.";
  };

  config = {
    telperion.home.extraOptions = {
      home.file = mkAliasDefinitions options.telperion.home.file;
      home.stateVersion = lib.mkOptionDefault config.system.stateVersion;
      xdg.configFile = mkAliasDefinitions options.telperion.home.configFile;
      xdg.enable = lib.mkDefault true;
    };

    home-manager = {
      # enables backing up existing files instead of erroring if conflicts exist
      backupFileExtension = "hm.old";

      useGlobalPkgs = true;
      useUserPackages = true;

      users.${config.telperion.user.name} = mkAliasDefinitions options.telperion.home.extraOptions;

      verbose = true;
    };
  };
}
