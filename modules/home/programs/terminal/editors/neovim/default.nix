{ config
, inputs
, lib
, osConfig ? { }
, pkgs
, system
, ...
}:
let
  inherit (lib.telperion) mkBoolOpt;
  inherit (lib) mkOption types;

  cfg = config.telperion.programs.terminal.editors.neovim;

  laurelinConfiguration = inputs.laurelin.nixvimConfigurations.${system}.laurelin;
  laurelinConfigurationExtended = laurelinConfiguration.extendModules {
    modules = [
      {
        config = {
          dependencies.yazi.enable = false;
        };
      }
    ] ++ cfg.extraModules;
  };
  laurelin = laurelinConfigurationExtended.config.build.package;
in
{
  options.telperion.programs.terminal.editors.neovim = {
    enable = lib.mkEnableOption "neovim";
    default = mkBoolOpt true "Whether to set Neovim as the session EDITOR";
    extraModules = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "Additional nixvim modules to extend the laurelin configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    home = {
      sessionVariables = {
        EDITOR = lib.mkIf cfg.default "nvim";
        MANPAGER = "nvim -c 'set ft=man bt=nowrite noswapfile nobk shada=\\\"NONE\\\" ro noma' +Man! -o -";
      };
      packages = [
        laurelin
        pkgs.nvrh
      ];
    };
  };
}
