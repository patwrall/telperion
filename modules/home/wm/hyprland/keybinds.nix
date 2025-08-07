{ config
, host
, ...
}:
let
  mod = "SUPER";

  mkBind = mod: key: action: "${mod}, ${key}, ${action}";
  wsaction = "${config.xdg.configHome}/hypr/scripts/wsaction.fish";
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      # Go to workspace #
      (mkBind mod "1" "exec, ${wsaction} workspace 1")
      (mkBind mod "2" "exec, ${wsaction} workspace 2")
      (mkBind mod "3" "exec, ${wsaction} workspace 3")
      (mkBind mod "4" "exec, ${wsaction} workspace 4")
      (mkBind mod "5" "exec, ${wsaction} workspace 5")
      (mkBind mod "6" "exec, ${wsaction} workspace 6")
      (mkBind mod "7" "exec, ${wsaction} workspace 7")
      (mkBind mod "8" "exec, ${wsaction} workspace 8")
      (mkBind mod "9" "exec, ${wsaction} workspace 9")
      (mkBind mod "0" "exec, ${wsaction} workspace 10")

      # Go to workspace group #
      (mkBind "CTRL+${mod}" "1" "exec, ${wsaction} -g workspace 1")
      (mkBind "CTRL+${mod}" "2" "exec, ${wsaction} -g workspace 2")
      (mkBind "CTRL+${mod}" "3" "exec, ${wsaction} -g workspace 3")
      (mkBind "CTRL+${mod}" "4" "exec, ${wsaction} -g workspace 4")
      (mkBind "CTRL+${mod}" "5" "exec, ${wsaction} -g workspace 5")
      (mkBind "CTRL+${mod}" "6" "exec, ${wsaction} -g workspace 6")
      (mkBind "CTRL+${mod}" "7" "exec, ${wsaction} -g workspace 7")
      (mkBind "CTRL+${mod}" "8" "exec, ${wsaction} -g workspace 8")
      (mkBind "CTRL+${mod}" "9" "exec, ${wsaction} -g workspace 9")
      (mkBind "CTRL+${mod}" "0" "exec, ${wsaction} -g workspace 10")

      # Go to workspace -1/+1
      (mkBind mod "mouse_down" "workspace -1")
      (mkBind mod "mouse_up" "workspace +1")

      # Move window to workspace #
      (mkBind "SHIFT+${mod}" "1" "exec, ${wsaction} -g movetoworkspace 1")
      (mkBind "SHIFT+${mod}" "2" "exec, ${wsaction} -g movetoworkspace 2")
      (mkBind "SHIFT+${mod}" "3" "exec, ${wsaction} -g movetoworkspace 3")
      (mkBind "SHIFT+${mod}" "4" "exec, ${wsaction} -g movetoworkspace 4")
      (mkBind "SHIFT+${mod}" "5" "exec, ${wsaction} -g movetoworkspace 5")
      (mkBind "SHIFT+${mod}" "6" "exec, ${wsaction} -g movetoworkspace 6")
      (mkBind "SHIFT+${mod}" "7" "exec, ${wsaction} -g movetoworkspace 7")
      (mkBind "SHIFT+${mod}" "8" "exec, ${wsaction} -g movetoworkspace 8")
      (mkBind "SHIFT+${mod}" "9" "exec, ${wsaction} -g movetoworkspace 9")
      (mkBind "SHIFT+${mod}" "0" "exec, ${wsaction} -g movetoworkspace 10")
      # Move window to workspace group #
      (mkBind "SHIFT+CTRL+${mod}" "1" "exec, ${wsaction} -g movetoworkspace 1")
      (mkBind "SHIFT+CTRL+${mod}" "2" "exec, ${wsaction} -g movetoworkspace 2")
      (mkBind "SHIFT+CTRL+${mod}" "3" "exec, ${wsaction} -g movetoworkspace 3")
      (mkBind "SHIFT+CTRL+${mod}" "4" "exec, ${wsaction} -g movetoworkspace 4")
      (mkBind "SHIFT+CTRL+${mod}" "5" "exec, ${wsaction} -g movetoworkspace 5")
      (mkBind "SHIFT+CTRL+${mod}" "6" "exec, ${wsaction} -g movetoworkspace 6")
      (mkBind "SHIFT+CTRL+${mod}" "7" "exec, ${wsaction} -g movetoworkspace 7")
      (mkBind "SHIFT+CTRL+${mod}" "8" "exec, ${wsaction} -g movetoworkspace 8")
      (mkBind "SHIFT+CTRL+${mod}" "9" "exec, ${wsaction} -g movetoworkspace 9")
      (mkBind "SHIFT+CTRL+${mod}" "0" "exec, ${wsaction} -g movetoworkspace 10")

    ];

    binde = [
      (mkBind "CTRL+${mod}" "Page_Down" "workspace - 1")
      (mkBind "CTRL+${mod}" "Page_Up" "workspace + 1")
      (mkBind "CTRL+${mod}" "left" "workspace - 1")
      (mkBind "CTRL+${mod}" "right" "workspace + 1")
    ];

    bindl = [ ];

    bindr = [ ];
  };
}
