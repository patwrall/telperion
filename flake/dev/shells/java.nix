{ mkShell
, pkgs
, lib
, ...
}:
mkShell {
  packages = with pkgs; [
    maven
    jdk17
    xorg.libX11
    xorg.libXtst
    xorg.libXxf86vm
    gtk3
    glib
    gdk-pixbuf
    pango
    cairo
    libglvnd
  ];

  shellHook = ''
    export JAVA_HOME="${pkgs.jdk17}/lib/openjdk"
    export PATH="$PATH:${pkgs.maven}/bin:$JAVA_HOME/bin"

    export LD_LIBRARY_PATH="${lib.makeLibraryPath [
      pkgs.xorg.libX11
      pkgs.xorg.libXtst
      pkgs.xorg.libXxf86vm
      pkgs.libGL
      pkgs.gtk3
      pkgs.glib.out
    ]}:$LD_LIBRARY_PATH"

    echo 🔨 Java DevShell
  '';
}

