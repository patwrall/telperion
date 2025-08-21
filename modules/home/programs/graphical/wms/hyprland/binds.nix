{ config
, lib
, pkgs
, osConfig ? { }
, ...
}:
let
  inherit (lib) mkIf getExe;

  cfg = config.telperion.programs.graphical.wms.hyprland;

  mkStartCommand = cmd:
    if (osConfig.programs.uwsm.enable or false) then "uwsm app -- ${cmd}" else "app2unit -- ${cmd}";

  mkExecBind = bind:
    let
      parts = lib.splitString "exec," bind;
      pre = lib.elemAt parts 0;
      cmd = lib.trim (lib.elemAt parts 1);
    in
    "${pre}exec, ${mkStartCommand cmd}";

  formatBinds = type: binds: lib.concatStringsSep "\n" (lib.map (b: "${type} = ${b}") binds);

  launcherBindi = [ "SUPER, Super_L, global, caelestia:launcher" ];
  launcherBindin = [
    "SUPER, catchall, global, caelestia:launcherInterrupt"
    "SUPER, mouse:272, global, caelestia:launcherInterrupt"
    "SUPER, mouse:273, global, caelestia:launcherInterrupt"
    "SUPER, mouse:274, global, caelestia:launcherInterrupt"
    "SUPER, mouse:275, global, caelestia:launcherInterrupt"
    "SUPER, mouse:276, global, caelestia:launcherInterrupt"
    "SUPER, mouse:277, global, caelestia:launcherInterrupt"
    "SUPER, mouse_up, global, caelestia:launcherInterrupt"
    "SUPER, mouse_down, global, caelestia:launcherInterrupt"
  ];

  appBinds = [
    "$kbTerminal, exec, $terminal"
    "SUPER, RETURN, exec, $terminal"
    "$kbBrowser, exec, $browser"
    "$kbEditor, exec, $editor"
    "$kbFileExplorer, exec, $fileExplorer"
    "CTRL_ALT, Escape, exec, qps"
    "CTRL_ALT, V, exec, pavucontrol"
  ];

  specialWsToggles = [
    "$kbSystemMonitor, exec, caelestia toggle sysmon"
    "$kbMusic, exec, caelestia toggle music"
    "$kbCommunication, exec, caelestia toggle communication"
    "$kbTodo, exec, caelestia toggle todo"
  ];

  regularBinds = [
    # Misc
    "$kbSession, global, caelestia:session"
    "$kbShowPanels, global, caelestia:showall"
    "$kbLock, global, caelestia:lock"
    # Workspaces
    "SUPER, mouse_down, workspace, -1"
    "SUPER, mouse_up, workspace, +1"
    "CTRL_SUPER, mouse_down, workspace, -10"
    "CTRL_SUPER, mouse_up, workspace, +10"
    "$kbToggleSpecialWs, exec, caelestia toggle specialws"
    # Move window to workspace
    "SUPER_ALT, mouse_down, movetoworkspace, -1"
    "SUPER_ALT, mouse_up, movetoworkspace, +1"
    "CTRL_SUPER_SHIFT, up, movetoworkspace, special:special"
    "CTRL_SUPER_SHIFT, down, movetoworkspace, e+0"
    "SUPER_ALT, S, movetoworkspace, special:special"
    # Window groups
    "$kbToggleGroup, togglegroup"
    "$kbUngroup, moveoutofgroup"
    "SUPER_SHIFT, Comma, lockactivegroup, toggle"
    # Window actions
    "SUPER, left, movefocus, l"
    "SUPER, right, movefocus, r"
    "SUPER, up, movefocus, u"
    "SUPER, down, movefocus, d"
    "SUPER_SHIFT, left, movewindow, l"
    "SUPER_SHIFT, right, movewindow, r"
    "SUPER_SHIFT, up, movewindow, u"
    "SUPER_SHIFT, down, movewindow, d"
    "CTRL_SUPER, Backslash, centerwindow, 1"
    "CTRL_SUPER_ALT, Backslash, resizeactive, exact 55% 70%"
    "CTRL_SUPER_ALT, Backslash, centerwindow, 1"
    "$kbWindowPip, exec, caelestia pip"
    "$kbPinWindow, pin"
    "$kbWindowFullscreen, fullscreen, 0"
    "$kbWindowBorderedFullscreen, fullscreen, 1"
    "$kbToggleWindowFloating, togglefloating,"
    "$kbCloseWindow, killactive,"
    # Utilities
    "SUPER_SHIFT, S, global, caelestia:screenshotFreeze"
    "SUPER_SHIFT_ALT, S, global, caelestia:screenshot"
    "SUPER_ALT, R, exec, caelestia record -s"
    "CTRL_ALT, R, exec, caelestia record"
    "SUPER_SHIFT_ALT, R, exec, caelestia record -r"
    "SUPER_SHIFT, C, exec, hyprpicker -a"
    # Sleep
    "SUPER_SHIFT, L, exec, systemctl suspend-then-hibernate"
    # Clipboard and emoji picker
    "SUPER, V, exec, pkill fuzzel || caelestia clipboard"
    "SUPER_ALT, V, exec, pkill fuzzel || caelestia clipboard -d"
    "SUPER, Period, exec, pkill fuzzel || caelestia emoji -p"
  ] ++ (lib.concatLists (builtins.genList
    (x:
      let
        wsaction = "${config.home.homeDirectory}/.config/hypr/scripts/wsaction.fish";
        ws_num = toString (x + 1);
        key_num = toString (x + 1 - (10 * ((x + 1) / 10)));
      in
      [
        "$kbGoToWs, ${key_num}, exec, ${wsaction} workspace ${ws_num}"
        "$kbGoToWsGroup, ${key_num}, exec, ${wsaction} -g workspace ${ws_num}"
        "$kbMoveWinToWs, ${key_num}, exec, ${wsaction} movetoworkspace ${ws_num}"
        "$kbMoveWinToWsGroup, ${key_num}, exec, ${wsaction} -g movetoworkspace ${ws_num}"
      ]) 10));

  releaseBinds = [
    "$kbClearNotifs, global, caelestia:clearNotifs"
    "$kbRestoreLock, exec, caelestia shell -d"
    "$kbRestoreLock, global, caelestia:lock"

    ", XF86MonBrightnessUp, global, caelestia:brightnessUp"
    ", XF86MonBrightnessDown, global, caelestia:brightnessDown"

    "CTRL_SUPER, Space, global, caelestia:mediaToggle"
    ", XF86AudioPlay, global, caelestia:mediaToggle"
    ", XF86AudioPause, global, caelestia:mediaToggle"
    "CTRL_SUPER, Equal, global, caelestia:mediaNext"
    ", XF86AudioNext, global, caelestia:mediaNext"
    "CTRL_SUPER, Minus, global, caelestia:mediaPrev"
    ", XF86AudioPrev, global, caelestia:mediaPrev"
    ", XF86AudioStop, global, caelestia:mediaStop"

    ", Print, exec, caelestia screenshot"

    ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    "SUPER_SHIFT, M, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

    "CTRL_SHIFT_ALT, V, exec, sleep 0.5s && ydotool type -d 1 \"$(cliphist list | head -1 | cliphist decode)\""
    "SUPER_ALT, F12, exec, notify-send -u low -i dialog-information-symbolic 'Test notification' \"Here's a long message\" -a 'Shell' -A \"Test1=Action 1\" -A \"Test2=Action 2\""
  ];

  repeatableReleaseBindsLE = [
    ", XF86AudioRaiseVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ $volumeStep%+"
    ", XF86AudioLowerVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ $volumeStep%-"
  ];

  repeatableReleaseBindsE = [
    "$kbPrevWs, workspace, -1"
    "$kbNextWs, workspace, +1"
    "SUPER, Page_Up, workspace, -1"
    "SUPER, Page_Down, workspace, +1"
    "SUPER_ALT, Page_Up, movetoworkspace, -1"
    "SUPER_ALT, Page_Down, movetoworkspace, +1"
    "CTRL_SUPER_SHIFT, right, movetoworkspace, +1"
    "CTRL_SUPER_SHIFT, left, movetoworkspace, -1"
    "$kbWindowGroupCycleNext, cyclenext, activewindow"
    "$kbWindowGroupCycleNext, cyclenext, prev, activewindow"
    "CTRL_ALT, Tab, changegroupactive, f"
    "CTRL_SHIFT_ALT, Tab, changegroupactive, b"
    "SUPER, Minus, splitratio, -0.1"
    "SUPER, Equal, splitratio, 0.1"
  ];

  mouseBinds = [
    "SUPER, mouse:272, movewindow"
    "$kbMoveWindow, movewindow"
    "SUPER, mouse:273, resizewindow"
    "$kbResizeWindow, resizewindow"
  ];

  repeatableBinds = [
    "CTRL_SUPER_SHIFT, R, exec, qs -c caelestia kill"
    "CTRL_SUPER_ALT, R, exec, qs -c caelestia kill; caelestia shell -d"
  ];
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      extraConfig = lib.concatStringsSep "\n" [
        "exec = hyprctl dispatch submap global"
        "submap = global"
        ""
        "# --- KEYBINDINGS (GENERATED BY NIX) ---"
        ""

        "# Launcher (MUST be at the top, or they wont work consistently)"
        (formatBinds "bindi" launcherBindi)
        (formatBinds "bindin" launcherBindin)

        (formatBinds "bind" ((lib.map mkExecBind (appBinds ++ specialWsToggles)) ++ regularBinds))
        (formatBinds "bindl" releaseBinds)
        (formatBinds "binde" repeatableReleaseBindsE)
        (formatBinds "bindle" repeatableReleaseBindsLE)
        (formatBinds "bindm" mouseBinds)
        (formatBinds "bindr" repeatableBinds)
      ];
    };
  };
}
