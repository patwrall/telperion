{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.graphical.addons.weylus;
in
{
  options.telperion.programs.graphical.addons.weylus = {
    enable = lib.mkEnableOption "weylus";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      weylus
    ];


    networking.firewall.allowedTCPPorts = [
      1701
      9001
    ];

    telperion = {
      user = {
        extraGroups = [
          "input"
        ];
      };
    };
  };
}
