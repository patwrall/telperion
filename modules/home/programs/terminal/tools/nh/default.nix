{ config
, lib
, osConfig ? { }
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.nh;
in
{
  options.telperion.programs.terminal.tools.nh = {
    enable = lib.mkEnableOption "nh";
  };

  config = mkIf cfg.enable {
    programs.nh = {
      enable = true;

      clean = {
        enable = true;
      };

      flake = "${config.home.homeDirectory}/khanelinix";
    };

    launchd.agents.nh-clean.config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      StandardErrorPath = osConfig.telperion.programs.terminal.tools.nh.logPaths.stderr;
      StandardOutPath = osConfig.telperion.programs.terminal.tools.nh.logPaths.stdout;
    };

    home = {
      sessionVariables = {
        NH_SEARCH_PLATFORM = 1;
      };
      shellAliases = {
        nixre = "nh ${if pkgs.stdenv.hostPlatform.isLinux then "os" else "darwin"} switch";
      };
    };
  };
}
