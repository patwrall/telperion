{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.common;
in
{
  options.telperion.suites.common = {
    enable = lib.mkEnableOption "common configuration";
  };

  config = mkIf cfg.enable {
    home = {
      file = {
        ".hushlogin".text = "";
      };

      sessionVariables = {
        LESSHISTFILE = "${config.xdg.cacheHome}/less.history";
        WGETRC = "${config.xdg.configHome}/wgetrc";
      };

      shellAliases = {
        # Closure size checking aliases
        ncs-sys = ''f(){ nix build ".#nixosConfigurations.$1.config.system.build.toplevel" --no-link && nix path-info --recursive --closure-size --human-readable $(nix eval --raw ".#nixosConfigurations.$1.config.system.build.toplevel.outPath") | tail -1; }; f'';
        ncs-darwin = ''f(){ nix build ".#darwinConfigurations.$1.config.system.build.toplevel" --no-link && nix path-info --recursive --closure-size --human-readable $(nix eval --raw ".#darwinConfigurations.$1.config.system.build.toplevel.outPath") | tail -1; }; f'';
        ncs-home = ''f(){ nix build ".#homeConfigurations.$1.activationPackage" --no-link && nix path-info --recursive --closure-size --human-readable $(nix eval --raw ".#homeConfigurations.$1.activationPackage.outPath") | tail -1; }; f'';
        ndu = "nix-du -s=200MB | dot -Tsvg > store.svg";
      };

      home.packages = with pkgs; [
        ncdu
        tree
        wikiman
        nix-du
        graphviz
      ];

      telperion = {
        programs = {
          terminal = {
            shell = {
              fish = enabled;
            };
          };
        };
      };
    };
  };
}
