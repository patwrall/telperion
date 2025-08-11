{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.virtualisation.podman;
in
{
  options.telperion.virtualisation.podman = {
    enable = lib.mkEnableOption "podman";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      podman-compose
      podman-desktop
    ];

    telperion = {
      user = {
        extraGroups = [
          "docker"
          "podman"
        ];
      };

      home.extraOptions = {
        home.shellAliases = {
          "docker-compose" = "podman-compose";
        };
      };
    };

    virtualisation = {
      podman = {
        inherit (cfg) enable;

        autoPrune = {
          enable = true;
          flags = [ "--all" ];
          dates = "weekly";
        };

        defaultNetwork.settings.dns_enabled = true;
        dockerCompat = true;
        dockerSocket.enable = true;
      };
    };
  };
}
