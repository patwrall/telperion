{ config
, lib
, ...
}:
let
  inherit (lib.telperion) mkOpt;

  cfg = config.telperion.security.sops;
in
{
  options.telperion.security.sops = {
    enable = lib.mkEnableOption "sops";
    defaultSopsFile = mkOpt lib.types.path null "Default sops file.";
  };

  config = lib.mkIf cfg.enable {
    sops = {
      inherit (cfg) defaultSopsFile;

      age = {
        keyFile = "${config.users.users.${config.telperion.user.name}.home}/.config/sops/age/keys.txt";
      };
    };
  };
}
