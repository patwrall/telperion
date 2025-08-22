{ config
, lib
, ...
}:
let
  inherit (lib) mkIf;

  cfg = config.telperion.programs.terminal.tools.carapace;
in
{
  options.telperion.programs.terminal.tools.carapace = {
    enable = lib.mkEnableOption "carapace";
  };

  config = mkIf cfg.enable {
    programs = {
      carapace = {
        enable = true;

        enableBashIntegration = true;
        enableFishIntegration = true;
        # Prefer fzf-tab plugin
        enableZshIntegration = false;
        enableNushellIntegration = true;
      };

      zsh.initContent = # Bash
        ''
          export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' 
          zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
          zstyle ':completion:*:git:*' group-order 'main commands' 'alias commands' 'external commands'
        '';
    };
  };
}
