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
      (mkBind "CTRL_${mod}" "1" "exec, ${wsaction} -g workspace 1")
      (mkBind "CTRL_${mod}" "2" "exec, ${wsaction} -g workspace 2")
      (mkBind "CTRL_${mod}" "3" "exec, ${wsaction} -g workspace 3")
      (mkBind "CTRL_${mod}" "4" "exec, ${wsaction} -g workspace 4")
      (mkBind "CTRL_${mod}" "5" "exec, ${wsaction} -g workspace 5")
      (mkBind "CTRL_${mod}" "6" "exec, ${wsaction} -g workspace 6")
      (mkBind "CTRL_${mod}" "7" "exec, ${wsaction} -g workspace 7")
      (mkBind "CTRL_${mod}" "8" "exec, ${wsaction} -g workspace 8")
      (mkBind "CTRL_${mod}" "9" "exec, ${wsaction} -g workspace 9")
      (mkBind "CTRL_${mod}" "0" "exec, ${wsaction} -g workspace 10")
    ];

    bindl = [ ];

    bindr = [ ];
  };
}
