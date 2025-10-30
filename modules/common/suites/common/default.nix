{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.suites.common;
in
{
  options.telperion.suites.common = {
    enable = lib.mkEnableOption "common configuration";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      app2unit
      coreutils
      curl
      fd
      file
      findutils
      killall
      lsof
      pciutils
      pkgs.telperion.trace-symlink
      pkgs.telperion.trace-which
      pkgs.telperion.why-depends
      tldr
      unzip
      wget
      xclip
    ];
  };
}
