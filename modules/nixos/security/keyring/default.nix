{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.security.keyring;
in
{
  options.telperion.security.keyring = {
    enable = lib.mkEnableOption "gnome keyring";
  };

  config = mkIf cfg.enable {
    # NOTE: Also enables services.gnome.gcr-ssh-agent apparently
    services.gnome.gnome-keyring.enable = true;
  };
}
