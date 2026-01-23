{ mkShell
, pkgs
, lib
, ...
}:
mkShell {
  packages = with pkgs; [
    maven
    jdk17
    jdk

    xorg.libX11
    xorg.libXext
    xorg.libXi
    xorg.libXrender
    xorg.libXrandr
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXfixes
    xorg.libXcomposite
    xorg.libXtst
    xorg.libxcb

    gtk3
    glib
    gdk-pixbuf
    pango
    cairo

    libglvnd
    libGL

    fontconfig
    freetype
    nss
  ];

  shellHook = ''
    export JAVA_HOME="${pkgs.jdk17}/lib/openjdk"
    export PATH="$PATH:${pkgs.maven}/bin:$JAVA_HOME/bin"

    export LD_LIBRARY_PATH="${
      lib.makeLibraryPath [
        pkgs.xorg.libX11
        pkgs.xorg.libXext
        pkgs.xorg.libXi
        pkgs.xorg.libXrender
        pkgs.xorg.libXrandr
        pkgs.xorg.libXcursor
        pkgs.xorg.libXdamage
        pkgs.xorg.libXfixes
        pkgs.xorg.libXcomposite
        pkgs.xorg.libXtst
        pkgs.xorg.libxcb

        pkgs.libGL
        pkgs.gtk3
        pkgs.glib.out
        pkgs.fontconfig
        pkgs.freetype
        pkgs.nss
      ]
    }:$LD_LIBRARY_PATH"

    echo 🔨 Java DevShell
  '';
}
