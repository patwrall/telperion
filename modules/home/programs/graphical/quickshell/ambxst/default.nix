{ config
, lib
, ...
}:
let
  cfg = config.telperion.programs.graphical.quickshell.ambxst;
in
{
  options.telperion.programs.graphical.quickshell.ambxst = {
    enable = lib.mkEnableOption "Ambxst shell integration";
  };

  config = lib.mkIf cfg.enable {
    home.activation = {
      # Ensure the file exists before hyprland sources it. Ambxst generates the
      # real content on first run; this placeholder prevents a startup glob error.
      createAmbxstHyprlandConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f "$HOME/.local/share/ambxst/hyprland.conf" ]; then
          mkdir -p "$HOME/.local/share/ambxst"
          touch "$HOME/.local/share/ambxst/hyprland.conf"
        fi
      '';

      # cli.sh copies defaults from the read-only Nix store, which leaves the
      # config JSON files as r--r--r--. Ambxst can never persist GUI changes
      # through those permissions. Make them writable after every switch.
      fixAmbxstConfigPerms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        config_dir="$HOME/.config/ambxst/config"
        if [ -d "$config_dir" ]; then
          chmod u+w "$config_dir"/*.json 2>/dev/null || true
        fi
      '';
    };

    wayland.windowManager.hyprland = {
      # exec-once is intentionally omitted: ambxst's generated hyprland.conf
      # (sourced below) already contains `exec-once = ambxst`. Adding it here
      # too causes a double launch on startup.
      # Source ambxst's generated config (keybinds, profile appearance settings).
      extraConfig = ''
        source = ${config.home.homeDirectory}/.local/share/ambxst/hyprland.conf
      '';
    };
  };
}
