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
    # Ensure the file exists before hyprland sources it. Ambxst generates the
    # real content on first run; this placeholder prevents a startup glob error.
    home.activation.createAmbxstHyprlandConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -f "$HOME/.local/share/ambxst/hyprland.conf" ]; then
        mkdir -p "$HOME/.local/share/ambxst"
        touch "$HOME/.local/share/ambxst/hyprland.conf"
      fi
    '';

    wayland.windowManager.hyprland = {
      settings.exec-once = [ "ambxst" ];
      # Source ambxst's generated config (keybinds, profile appearance settings).
      extraConfig = ''
        source = ${config.home.homeDirectory}/.local/share/ambxst/hyprland.conf
      '';
    };
  };
}
