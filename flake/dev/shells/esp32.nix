{ mkShell
, pkgs
, ...
}:
mkShell {
  packages = with pkgs; [
    # Flashing and serial tools
    esptool
    picocom

    # Build system (used by idf.py internally)
    cmake
    ninja
    ccache

    # Python (ESP-IDF requires Python 3.x)
    (python3.withPackages (ps: with ps; [
      pip
      virtualenv
      pyserial
      cryptography
      pyparsing
      future
      setuptools
    ]))
  ];

  shellHook = ''

    echo 🔌 ESP32 DevShell

    # Source ESP-IDF if installed
    IDF_CANDIDATES=(
      "$HOME/esp/esp-idf/export.sh"
      "$HOME/.espressif/esp-idf/export.sh"
      "/opt/esp-idf/export.sh"
    )

    IDF_SOURCED=0
    for candidate in "''${IDF_CANDIDATES[@]}"; do
      if [ -f "$candidate" ]; then
        source "$candidate" > /dev/null 2>&1
        echo "  ✓ ESP-IDF sourced from $candidate"
        IDF_SOURCED=1
        break
      fi
    done

    if [ "$IDF_SOURCED" -eq 0 ]; then
      echo "  ⚠ ESP-IDF not found. Install it with:"
      echo "    mkdir -p ~/esp && cd ~/esp"
      echo "    git clone --recursive https://github.com/espressif/esp-idf.git"
      echo "    cd esp-idf && ./install.sh esp32"
    fi

  '';
}
