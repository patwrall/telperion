{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.shell.fish;
in
{
  options.telperion.programs.terminal.shell.fish = {
    enable = lib.mkEnableOption "fish";
  };

  config = mkIf cfg.enable {
    xdg.configFile."fish/functions" = {
      source = lib.cleanSourceWith { src = lib.cleanSource ./functions/.; };
      recursive = true;
    };

    programs.fish = {
      enable = true;

      interactiveShellInit =
        # fish
        ''
          # 1password plugin
          if [ -f ~/.config/op/plugins.sh ];
              source ~/.config/op/plugins.sh
          end
        ''
        + '' 
          set fish_greeting
        '';

      plugins = [
        {
          name = "autopair";
          inherit (pkgs.fishPlugins.autopair) src;
        }
        {
          name = "done";
          inherit (pkgs.fishPlugins.done) src;
        }
        {
          name = "fzf-fish";
          inherit (pkgs.fishPlugins.fzf-fish) src;
        }
        {
          name = "sponge";
          inherit (pkgs.fishPlugins.sponge) src;
        }
        {
          name = "z";
          inherit (pkgs.fishPlugins.z) src;
        }
      ];
    };
  };
}
