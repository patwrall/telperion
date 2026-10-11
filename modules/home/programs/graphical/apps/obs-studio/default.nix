{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.telperion.programs.graphical.apps.obs-studio;

  # The desktop sets nixpkgs.config.cudaSupport, which would build OBS and the
  # plugin's whole closure (onnxruntime, opencv, cuDNN, TensorRT) from source:
  # tens of GB and no cache hits. Take them from a CUDA-free package set
  # instead. NVENC recording does not need it: OBS loads the encoder at runtime.
  pkgsNoCuda = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // { cudaSupport = false; };
  };

in
{
  options.telperion.programs.graphical.apps.obs-studio = {
    enable = mkEnableOption "obs-studio";
  };

  config = mkIf cfg.enable {
    programs.obs-studio = {
      enable = true;
      package = pkgsNoCuda.obs-studio;
      plugins = [ pkgsNoCuda.obs-studio-plugins.obs-backgroundremoval ];
    };
  };
}
