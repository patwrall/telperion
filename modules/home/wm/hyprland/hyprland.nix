{ pkgs
, ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd = {
      enable = true;
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };
    xwayland = {
      enable = true;
    };

    settings = {
      input = {
        kb_layout = "us";
        numlock_by_default = false;
        repeat_delay = 250;
        repeat_rate = 35;

        focus_on_close = 1;

        touchpad = {
          natural_scroll = "yes";
          disable_while_typing = true;
          scroll_factor = 0.3;
        };
      };

      binds = {
        scroll_event_delay = 0;
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

      general = {
        "$modifier" = "SUPER";
        layout = "dwindle";
        allow_tearing = false;
        gaps_workspaces = 20;
      };

      dwindle = {
        preserve_split = true;
        smart_split = false;
        smart_resizing = true;
      };

      group = {
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
      };

      debug = {
        error_position = 1;
      };
    };
  };

  xdg.configFile."hypr/scripts/wsaction.fish" = {
    source = ./scripts/wsaction.fish;
    executable = true;
  };
}

