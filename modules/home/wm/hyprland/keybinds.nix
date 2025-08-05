{ host
, ...
}:
let
  inherit (import ../../../../hosts/${host}/variables.nix) terminal;
  mkBind = mod: key: action: "${mod}, ${key}, ${action}";
  mod = "SUPER";
in
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      (mkBind mod "RETURN" "exec, ${terminal}")
      (mkBind mod "Q" "killactive,")

      (mkBind mod "1" "workspace, 1")
      (mkBind mod "2" "workspace, 2")
      (mkBind mod "3" "workspace, 3")
      (mkBind mod "4" "workspace, 4")
      (mkBind mod "5" "workspace, 5")
      (mkBind mod "6" "workspace, 6")
      (mkBind mod "7" "workspace, 7")
      (mkBind mod "8" "workspace, 8")
      (mkBind mod "9" "workspace, 9")
      (mkBind mod "0" "workspace, 10")

      (mkBind "${mod}_SHIFT" "1" "movetoworkspace, 1")
      (mkBind "${mod}_SHIFT" "2" "movetoworkspace, 2")
      (mkBind "${mod}_SHIFT" "3" "movetoworkspace, 3")
      (mkBind "${mod}_SHIFT" "4" "movetoworkspace, 4")
      (mkBind "${mod}_SHIFT" "5" "movetoworkspace, 5")
    ];

    bindl = [ ];

    bindr = [ ];
  };
}
