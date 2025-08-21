{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf getExe;

  cfg = config.telperion.programs.graphical.wms.hyprland;
in
{

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      settings = {
        animations = {
          enabled = "yes";

          bezier = [
            "specialWorkSwitch, 0.05, 0.7, 0.1, 1"
            "emphasizedAccel, 0.3, 0, 0.8, 0.15"
            "emphasizedDecel, 0.05, 0.7, 0.1, 1"
            "standard, 0.2, 0, 0, 1"
          ];

          animation = [
            "layersIn, 1, 5, emphasizedDecel, slide"
            "layersOut, 1, 4, emphasizedAccel, slide"
            "fadeLayers, 1, 5, standard"

            "windowsIn, 1, 5, emphasizedDecel"
            "windowsOut, 1, 3, emphasizedAccel"
            "windowsMove, 1, 6, standard"
            "workspaces, 1, 5, standard"

            "specialWorkspace, 1, 4, specialWorkSwitch, slidefadevert 15%"

            "fade, 1, 6, standard"
            "fadeDim, 1, 6, standard"
            "border, 1, 6, standard"
          ];
        };

        cursor = {
          enable_hyprcursor = true;
          sync_gsettings_theme = true;
        };

        debug = mkIf cfg.enableDebug {
          colored_stdout_logs = true;
          disable_logs = false;
          enable_stdout_logs = true;
          error_position = -1;
        };

        decoration = {
          rounding = 10;

          blur = {
            enabled = true;
            xray = false;
            special = false;
            ignore_opacity = true;
            new_optimizations = true;
            popups = true;
            input_methods = true;
            size = 8;
            passes = 2;
          };

          shadow = {
            enabled = true;
            range = 20;
            render_power = 3;
            color = "rgba($surfaced4)";
          };
        };

        general = {
          layout = "dwindle";
          allow_tearing = false;
          gaps_workspaces = 20;
          gaps_in = 10;
          gaps_out = 40;
          border_size = 3;
        };

        dwindle = {
          preserve_split = true;
          smart_split = false;
          smart_resizing = true;
        };

        gestures = {
          workspace_swipe = true;
          workspace_swipe_distance = 700;
          workspace_swipe_fingers = 4;
          workspace_swipe_cancel_ratio = 0.15;
          workspace_swipe_min_speed_to_force = 5;
          workspace_swipe_direction_lock = true;
          workspace_swipe_direction_lock_threshold = 10;
          workspace_swipe_create_new = true;
        };

        input = {
          kb_layout = "us";
          numlock_by_default = true;
          repeat_delay = 250;
          repeat_rate = 35;

          focus_on_close = 1;

          touchpad = {
            natural_scroll = true;
            disable_while_typing = true;
            scroll_factor = 0.3;
          };
        };

        group = {
          "col.border_active" = "rgba($primarye6)";
          "col.border_inactive" = "rgba($onSurfaceVariant11)";
          "col.border_locked_active" = "rgba($primarye6)";
          "col.border_locked_inactive" = "rgba($onSurfaceVariant11)";

          groupbar = {
            font_family = "JetBrains Mono NF";
            font_size = 15;
            gradients = true;
            gradient_round_only_edges = false;
            gradient_rounding = 5;
            height = 25;
            indicator_height = 0;
            gaps_in = 3;
            gaps_out = 3;

            text_color = "rgb($onPrimary)";
            "col.active" = "rgba($primaryd4)";
            "col.inactive" = "rgba($outlined4)";
            "col.locked_active" = "rgba($primaryd4)";
            "col.locked_inactive" = "rgba($secondaryd4)";
          };
        };

        misc = {
          vfr = true;
          vrr = 1;

          animate_manual_resizes = false;
          animate_mouse_windowdragging = false;

          disable_hyprland_logo = true;
          force_default_wallpaper = 0;

          new_window_takes_over_fullscreen = 2;
          allow_session_lock_restore = true;
          middle_click_paste = false;
          focus_on_activate = true;
          session_lock_xray = true;

          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;

          background_color = "rgb($surfaceContainer)";
        };

        "$terminal" = "${getExe pkgs.foot}";
        "$browser" = "";
        "$editor" = "${getExe pkgs.neovim}";
        "$fileExplorer" = "${getExe pkgs.nautilus}";

        "$volumeStep" = "10";

        # Workspaces
        "$kbMoveWinToWs" = "SUPER_ALT";
        "$kbMoveWinToWsGroup" = "CTRL_SUPER_ALT";
        "$kbGoToWs" = "SUPER";
        "$kbGoToWsGroup" = "CTRL_SUPER";

        "$kbNextWs" = "CTRL_SUPER, right";
        "$kbPrevWs" = "CTRL_SUPER, left";

        "$kbToggleSpecialWs" = "SUPER, S";

        # Window Groups
        "$kbWindowGroupCycleNext" = "ALT, Tab";
        "$kbWindowGroupCyclePrev" = "SHIFT_ALT, Tab";
        "$kbUngroup" = "SUPER, U";
        "$kbToggleGroup" = "SUPER, Comma";

        # Window Actions
        "$kbMoveWindow" = "SUPER, Z";
        "$kbResizeWindow" = "SUPER, X";
        "$kbWindowPip" = "SUPER_ALT, Backslash";
        "$kbPinWindow" = "SUPER, P";
        "$kbWindowFullscreen" = "SUPER, F";
        "$kbWindowBorderedFullscreen" = "SUPER_ALT, F";
        "$kbToggleWindowFloating" = "SUPER_ALT, Space";
        "$kbCloseWindow" = "SUPER, Q";

        # Special Workspace Toggles
        "$kbSystemMonitor" = "CTRL_SHIFT, Escape";
        "$kbMusic" = "SUPER, M";
        "$kbCommunication" = "SUPER, D";
        "$kbTodo" = "SUPER, R";

        # Apps
        "$kbTerminal" = "SUPER, T";
        "$kbBrowser" = "SUPER, W";
        "$kbEditor" = "SUPER, C";
        "$kbFileExplorer" = "SUPER, E";

        # Mics
        "$kbSession" = "CTRL_ALT, Delete";
        "$kbClearNotifs" = "CTRL_ALT, C";
        "$kbShowPanels" = "SUPER, K";
        "$kbLock" = "SUPER, L";
        "$kbRestoreLock" = "SUPER_ALT, L";
      };
    };
  };
}
