{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.telperion.programs.terminal.tools.tmux;
in
{
  options.telperion.programs.terminal.tools.tmux = {
    enable = lib.mkEnableOption "tmux";
  };

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      shell = "${pkgs.fish}/bin/fish";
      terminal = "tmux-256color";
      historyLimit = 50000;
      mouse = true;
      keyMode = "vi";
      prefix = "C-Space";
      baseIndex = 1;
      escapeTime = 0;

      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = continuum;
          extraConfig = ''
            set -g @continuum-restore 'on'
            set -g @continuum-save-interval '10'
          '';
        }
      ];

      extraConfig = ''
        # True color + undercurl support
        set -ga terminal-overrides ",*256col*:Tc"
        set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
        set -as terminal-features ',*:RGB'

        # Extended keys — lets tmux forward C-/ and other ambiguous keys correctly
        # Pane numbering
        set -g pane-base-index 1
        set -g renumber-windows on

        # Don't exit when the last pane closes — go to next window
        set -g remain-on-exit off

        # Faster key repeat
        set -g repeat-time 300

        # ── Pane navigation ──
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # ── Splits ──
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"

        # ── Pane / window management ──
        bind x kill-pane
        bind z resize-pane -Z
        bind c new-window -c "#{pane_current_path}"
        bind < swap-window -d -t -1
        bind > swap-window -d -t +1
        bind r command-prompt -I "#{window_name}" "rename-window '%%'"
        bind d detach-client
        bind K confirm-before -p "kill session?" kill-session

        # ── vi copy mode ──
        bind -T copy-mode-vi v   send-keys -X begin-selection
        bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
        bind -T copy-mode-vi y   send-keys -X copy-selection-and-cancel
        bind -T copy-mode-vi j   send-keys -X scroll-down
        bind -T copy-mode-vi k   send-keys -X scroll-up
        bind -T copy-mode-vi q   send-keys -X cancel
        bind -T copy-mode-vi Escape send-keys -X cancel

        # ── Minimal status line (catppuccin macchiato palette) ──
        set -g status-position top
        set -g status-interval 5
        set -g status-justify left
        set -g status-style "bg=#1e2030,fg=#cad3f5"

        set -g pane-border-style "fg=#363a4f"
        set -g pane-active-border-style "fg=#b7bdf8"
        set -g message-style "bg=#1e2030,fg=#cad3f5,bold"
        set -g mode-style "bg=#b7bdf8,fg=#1e2030"

        set -g window-status-separator ""
        set -g window-status-format         "#[fg=#6e738d,bg=#1e2030] #I:#W "
        set -g window-status-current-format "#[fg=#b7bdf8,bg=#1e2030,bold] #I:#W "

        set -g status-left-length 50
        set -g status-right-length 80
        set -g status-left  "#[fg=#b7bdf8,bold]  #S #[fg=#494d64]│ "
        set -g status-right "#[fg=#b7bdf8] #{b:pane_current_path} #[fg=#494d64]│ #[fg=#cad3f5]%H:%M"
      '';
    };

    programs.fish.functions = {
      # tmux open — create or attach a project session with the dev layout
      # Mirrors the Zellij `zo` function / dev layout
      to = ''
        set session_name (basename (pwd))
        set session_cwd (pwd)

        if tmux has-session -t $session_name 2>/dev/null
            tmux attach -t $session_name
            return
        end

        # 1: Project — nvim
        tmux new-session -d -s $session_name -n "Project" -c $session_cwd
        tmux send-keys -t "$session_name:Project" "nvim" Enter

        # 2: Git — lazygit
        tmux new-window -t $session_name -n "Git" -c $session_cwd
        tmux send-keys -t "$session_name:Git" "lazygit" Enter

        # 3: Shell — bare fish
        tmux new-window -t $session_name -n "Shell" -c $session_cwd

        # 4: Claude — continue last conversation or start fresh
        tmux new-window -t $session_name -n "Claude" -c $session_cwd
        tmux send-keys -t "$session_name:Claude" "claude --continue; or claude" Enter

        tmux select-window -t "$session_name:Project"
        tmux attach -t $session_name
      '';

      # short entry point: t → create/attach dev session in cwd
      t = ''
        to
      '';

      # tmux attach — fuzzy-select from existing sessions (mirrors zas)
      ta = ''
        set session (tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --prompt="tmux session: ")
        if test -n "$session"
            tmux attach -t $session
        end
      '';
    };
  };
}
