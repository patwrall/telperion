{ mkShell
, pkgs
, lib
, ...
}:
let
  # `pkgs.cudaPackages` floats to whatever nixpkgs currently defaults to,
  # which drifts out of sync with the CUDA major version pip resolves for
  # a bare `torch` install (13.0, the current default PyPI wheel as of
  # torch 2.13). Pin explicitly to match; bump this alongside whatever
  # CUDA major torch resolves to when that changes.
  cudaPackages = pkgs.cudaPackages_13_0;

  # nvcc pins a narrow range of supported host compilers; use the stdenv
  # nixpkgs already validated against the pinned cudaPackages version
  # instead of the default stdenv's gcc.
  # https://nixos.org/manual/nixpkgs/stable/#sec-cuda
  cudaStdenv = cudaPackages.backendStdenv;
in
mkShell {
  stdenv = cudaStdenv;

  packages = with pkgs; [
    ccache
    cmake
    ninja

    cudaPackages.cudatoolkit

    (python3.withPackages (
      ps: with ps; [
        ipython
        numpy
        pip
        pytest
      ]
    ))
  ];

  shellHook = ''
    export CUDA_HOME="${cudaPackages.cudatoolkit}"
    export CUDA_PATH="$CUDA_HOME"

    # The toolkit only ships the linker stub for libcuda.so; the real
    # userspace driver is bind-mounted here by the NixOS nvidia module.
    # cc.cc.lib (libstdc++ etc.) is for prebuilt pip wheels (e.g. torch's
    # _C.so): they dlopen() it at import time, which bypasses nix-ld
    # (that only intercepts process exec, not dlopen from an already-native
    # binary like this shell's python3).
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:${
      lib.makeLibraryPath [ cudaPackages.cudatoolkit cudaStdenv.cc.cc.lib ]
    }:$LD_LIBRARY_PATH"

    if [ ! -d .venv ]; then
      python3 -m venv .venv
    fi
    source .venv/bin/activate

    echo 🔥 CUDA DevShell
  '';
}
