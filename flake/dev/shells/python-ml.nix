{ mkShell
, pkgs
, ...
}:
mkShell {
  packages = with pkgs; [
    black
    jupyter
    mypy
    ruff

    (python3.withPackages (
      ps: with ps; [
        ipykernel
        torchWithCuda
        numpy
        pandas
        pynvim
        scikit-learn
        matplotlib

        # Tools for interactivity and testing
        ipython
        pytest
        pip
      ]
    ))
  ];

  shellHook = ''
    echo "✅ Python ML DevShell Activated"
    # echo "🚀 Starting Jupyter kernel in the background..."
    # bash -c '(nohup jupyter kernel --kernel=python3 >/dev/null 2>&1 &)'
  '';
}
