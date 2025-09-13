{ mkShell
, pkgs
, ...
}:
mkShell {
  packages = with pkgs; [
    black
    jupyter
    mypy
    quarto
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
    echo "🚀 ML DevShell Activated"
  '';
}
