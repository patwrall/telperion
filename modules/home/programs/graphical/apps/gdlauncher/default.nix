{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.gdlauncher;

in
{
  options.telperion.programs.graphical.apps.gdlauncher = {
    enable = mkEnableOption "gdlauncher";
  };

  config = mkIf cfg.enable {
    home.packages = [
      # Wrap with NVIDIA GLX vendor so Minecraft's GLFW can create a context.
      (pkgs.symlinkJoin {
        name = "gdlauncher-carbon";
        paths = [ pkgs.gdlauncher-carbon ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/gdlauncher-carbon \
            --set __GLX_VENDOR_LIBRARY_NAME nvidia \
            --set LIBVA_DRIVER_NAME nvidia
        '';
      })
    ];

  };
}
