{ config
, lib
, pkgs
, osConfig ? { }
, ...
}:
let
  inherit (lib) mkIf getExe;

  cfg = config.telperion.programs.graphical.wms.hyprland;

  mkStartCommand =
    cmd:
    if (osConfig.programs.uwsm.enable or false) then "uwsm app -- ${cmd}" else "run-as-service ${cmd}";
  mkExecBind =
    bind:
    let
      parts = builtins.split "exec, " bind;
      pre = builtins.head parts;
      cmd = builtins.elemAt parts 2;
    in
    "${pre}exec, ${mkStartCommand cmd}";
in
{
  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        exec = [ "hyprctl dispatch submap global" ];
        submap = "global";

        # Bindi - For keypresses that are not repeatable
        bindi = [
          "SUPER, Super_L, global, caelestia:launcher"
        ];

        # Bindin - For keypresses that are not repeatable and inhibit the key
        bindin = [
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

        # Bindr - Repeatable binds
        bindr = [
          "CTRL_SUPER_SHIFT, R, exec, qs -c caelestia kill"
          "CTRL_SUPER_ALT, R, exec, qs -c caelestia kill; caelestia shell -d"
        ];

        # Bindl - Binds that are triggered on release
        bindl = [
          # Misc
          "$kbClearNotifs, global, caelestia:clearNotifs"

          # Restore lock
          "$kbRestoreLock, exec, caelestia shell -d"
          "$kbRestoreLock, global, caelestia:lock"

          # Brightness
          ", XF86MonBrightnessUp, global, caelestia:brightnessUp"
          ", XF86MonBrightnessDown, global, caelestia:brightnessDown"

          # Media 
          "Super+Shift, P, global, caelestia:mediaToggle"
          ", XF86AudioPlay, global, caelestia:mediaToggle"
          ", XF86AudioPause, global, caelestia:mediaToggle"
          "Super+Shift, N, global, caelestia:mediaNext"
          ", XF86AudioNext, global, caelestia:mediaNext"
          "Super+Shift, B, global, caelestia:mediaPrev"
          ", XF86AudioPrev, global, caelestia:mediaPrev"
          ", XF86AudioStop, global, caelestia:mediaStop"

          # Utilities
          ", Print, exec, caelestia screenshot"

          # Volume
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          "SUPER_SHIFT, M, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

          # Clipboard
          "SUPER, V, exec, sleep 0.5s && ydotool type -d 1 \"$(cliphist list | head -1 | cliphist decode)\""

          # Testing
          "SUPER_ALT, F12, exec, notify-send -u low -i dialog-information-symbolic 'Test notification' \"Here is a long message\" -a 'Shell' -A \"Test1=Action 1\" -A \"Test2=Action 2\""
        ];

        # Bindle - Repeatable binds on release
        bindle = [
          ", XF86AudioRaiseVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ $volumeStep%+"
          ", XF86AudioLowerVolume, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ $volumeStep%-"
        ];

        # Binde - Binds that are triggered on release and repeatable
        binde = [
          # Workspaces
          "$kbPrevWs, workspace, -1"
          "$kbNextWs, workspace, +1"
          "SUPER, Page_Up, workspace, -1"
          "SUPER, Page_Down, workspace, +1"

          # Move window to workspace
          "SUPER_ALT, Page_Up, movetoworkspace, -1"
          "SUPER_ALT, Page_Down, movetoworkspace, +1"
          "CTRL_SUPER_SHIFT, right, movetoworkspace, +1"
          "CTRL_SUPER_SHIFT, left, movetoworkspace, -1"

          # Window groups
          "$kbWindowGroupCycleNext, cyclenext, activewindow"
          "$kbWindowGroupCycleNext, cyclenext, prev, activewindow"
          "CTRL_ALT, Tab, changegroupactive, f"
          "CTRL_SHIFT_ALT, Tab, changegroupactive, b"

          # Window actions
          "SUPER, Semicolon, splitratio, -0.1"
          "SUPER, Apostrophe, splitratio, 0.1"
        ];

        # Bindm - Binds for mouse buttons
        bindm = [
          "SUPER, mouse:272, movewindow"
          "$kbMoveWindow, movewindow"
          "SUPER, mouse:273, resizewindow"
          "$kbResizeWindow, resizewindow"
        ];

        bind =
          let
            appBinds = [
              "$kbTerminal, exec, app2unit -- $terminal"
              "SUPER_ENTER, exec, app2unit -- $terminal"
              "$kbBrowser, exec, app2unit -- $browser"
              "$kbEditor, exec, app2unit -- $editor"
              "$kbFileExplorer, exec, app2unit -- $fileExplorer"
              "CTRL_ALT, Escape, exec, app2unit -- qps"
              "CTRL_SUPER, V, exec, app2unit -- pavucontrol"
            ];

            miscBinds = [
              "$kbSession, global, caelestia:session"
              "$kbShowPanels, global, caelestia:showall"
              "$kbLock, global, caelestia:lock"
            ];

            workspaceBinds = [
              "SUPER, mouse_down, workspace, -1"
              "SUPER, mouse_up, workspace, +1"
              "CTRL_SUPER, mouse_down, workspace, -10"
              "CTRL_SUPER, mouse_up, workspace, +10"
              "$kbToggleSpecialWs, exec, caelestia toggle specialws"
            ];

            moveWindowToWsBinds = [
              "SUPER_ALT, mouse_down, movetoworkspace, -1"
              "SUPER_ALT, mouse_up, movetoworkspace, +1"
              "CTRL_SUPER_SHIFT, up, movetoworkspace, special:special"
              "CTRL_SUPER_SHIFT, down, movetoworkspace, e+0"
              "SUPER_ALT, S, movetoworkspace, special:special"
            ];

            windowGroupBinds = [
              "$kbToggleGroup, togglegroup"
              "$kbUngroup, moveoutofgroup"
              "SUPER_SHIFT, Comma, lockactivegroup, toggle"
            ];

            windowActionBinds = [
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
            ];

            specialWsToggles = [
              "$kbSystemMonitor, exec, caelestia toggle sysmon"
              "$kbMusic, exec, caelestia toggle music"
              "$kbCommunication, exec, caelestia toggle communication"
              "$kbTodo, exec, caelestia toggle todo"
            ];

            utilityBinds = [
              "SUPER_SHIFT, S, global, caelestia:screenshotFreeze"
              "SUPER_SHIFT_ALT, S, global, caelestia:screenshot"
              "SUPER_ALT, R, exec, caelestia record -s"
              "CTRL_ALT, R, exec, caelestia record"
              "SUPER_SHIFT_ALT, R, exec, caelestia record -r"
              "SUPER_SHIFT, C, exec, hyprpicker -a"
            ];

            sleepBinds = [
              "SUPER_SHIFT, L, exec, systemctl suspend-then-hibernate"
            ];

            clipboardEmojiBinds = [
              "SUPER, V, exec, pkill fuzzel || caelestia clipboard"
              "SUPER_ALT, V, exec, pkill fuzzel || caelestia clipboard -d"
              "SUPER, Period, exec, pkill fuzzel || caelestia emoji -p"
            ];
          in
          appBinds
          ++ miscBinds
          ++ workspaceBinds
          ++ moveWindowToWsBinds
          ++ windowGroupBinds
          ++ windowActionBinds
          ++ specialWsToggles
          ++ utilityBinds
          ++ sleepBinds
          ++ clipboardEmojiBinds
          ++ (
            lib.concatLists
              (builtins.genList
                (x:
                  let
                    wsaction = "${config.home.homeDirectory}/.config/hypr/scripts/wsaction.fish";

                    ws_num = lib.toString (x + 1);
                    key_num = lib.toString (x + 1 - (10 * ((x + 1) / 10)));
                  in
                  [
                    # Go to workspace #
                    "$kbGoToWs, ${key_num}, exec, ${wsaction} workspace ${ws_num}"
                    # Go to workspace group #
                    "$kbGoToWsGroup, ${key_num}, exec, ${wsaction} -g workspace ${ws_num}"
                    # Move window to workspace #
                    "$kbMoveWinToWs, ${key_num}, exec, ${wsaction} movetoworkspace ${ws_num}"
                    # Move window to workspace group #
                    "$kbMoveWinToWsGroup, ${key_num}, exec, ${wsaction} -g movetoworkspace ${ws_num}"
                  ]
                ) 10
              )
          );
      };
    };
  };
}
