{ config
, lib
, inputs
, system
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.browsers.zen-browser;

in
{
  options.telperion.programs.graphical.browsers.zen-browser = {
    enable = mkEnableOption "zen-browser";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      inputs.zen-browser.packages.${system}.zen-browser
    ];
  };
}
