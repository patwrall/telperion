{ config
, lib
, pkgs
, osConfig ? { }
, ...
}:
let
  inherit (lib) mkIf mkEnableOption getExe;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.programs.graphical.wms.hyprland;

  historicalLogAliases = builtins.listToAttrs (
    builtins.genList
      (x: {
        name = "hl${toString (x + 1)}";
        value = "cat $(ls -td $XDG_RUNTIME_DIR/hypr/*/ | sed -n '${toString (x + 2)}p')/hyprland.log 2>/dev/null || echo 'No historical log found at position ${toString (x + 1)}'";
      }) 4
  );

  historicalCrashAliases = builtins.listToAttrs (
    builtins.genList
      (x: {
        name = "hlc${toString (x + 1)}";
        value = "cat ${config.xdg.cacheHome}/hyprland/$(command ls -t ${config.xdg.cacheHome}/hyprland/ | grep 'hyprlandCrashReport' | head -n ${toString (x + 2)} | tail -n 1)";
      }) 4
  );
in
{
  options.telperion.programs.graphical.wms.hyprland = {
    enable = mkEnableOption "Hyprland";
    enableDebug = mkEnableOption "debug config";
    appendConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra configuration lines to add to bottom of `~/.config/hypr/hyprland.conf`.
      '';
    };
    prependConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra configuration lines to add to top of `~/.config/hypr/hyprland.conf`.
      '';
    };
  };

  imports = [ ];

  config = mkIf cfg.enable {
    home = {
      # pointerCursor.hyprcursor = {
      #   enable = true;
      # };

      sessionVariables = lib.mkIf (!(osConfig.programs.uwsm.enable or false)) (
        {
          CLUTTER_BACKEND = "wayland";
          MOZ_ENABLE_WAYLAND = "1";
          MOZ_USE_XINPUT2 = "1";
          # NOTE: causes gldriverquery crash on wayland
          # SDL_VIDEODRIVER = "wayland";
          WLR_DRM_NO_ATOMIC = "1";
          XDG_SESSION_TYPE = "wayland";
          _JAVA_AWT_WM_NONREPARENTING = "1";
          __GL_GSYNC_ALLOWED = "0";
          __GL_VRR_ALLOWED = "0";
        }
        // mkIf cfg.enableDebug {
          AQ_TRACE = "1";
          HYPRLAND_LOG_WLR = "1";
          HYPRLAND_TRACE = "1";
        }
      );

      shellAliases = {
        hl = "cat $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log";
        hlc = ''
          local report_dir="${config.xdg.cacheHome}/hyprland"
          local latest_report

          latest_report=$(command ls -t "$report_dir" 2>/dev/null | grep 'hyprlandCrashReport' | head -n 1)

          if [[ -n "$latest_report" ]]; then
              cat "''${report_dir}/''${latest_report}"
          else
              echo "No Hyprland crash reports found. ✨"
          fi
        '';
        hlw = ''watch -n 0.1 "grep -v \"arranged\" $XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log | tail -n 40"'';
      }
      // historicalLogAliases
      // historicalCrashAliases;
    };

    telperion = { };

    services.hyprpolkitagent = enabled;

    wayland.windowManager.hyprland =
      let
        systemctl = lib.getExe' pkgs.systemd "systemctl";
      in
      {
        enable = true;

        extraConfig =
          # bash
          ''
            ${cfg.prependConfig}

            ${cfg.appendConfig}
          '';

        package = lib.mkIf (osConfig ? programs.hyprland.package) osConfig.programs.hyprland.package;
        portalPackage = lib.mkIf
          (
            osConfig ? programs.hyprland.portalPackage
          )
          osConfig.programs.hyprland.portalPackage;

        settings = { };

        systemd = {
          enable = !(osConfig.programs.uwsm.enable or false);
          enableXdgAutostart = true;
          extraCommands = [
            "${systemctl} --user stop hyprland-session.target"
            "${systemctl} --user reset-failed"
            "${systemctl} --user start hyprland-session.target"
          ];

          variables = [
            "--all"
          ];
        };

        xwayland.enable = true;
      };
  };
}
