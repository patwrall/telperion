{ mkShell
, pkgs
, ...
}:
mkShell {
  packages = with pkgs; [
    jdk
    jdk8
    jdk11
    jdk17
    openjfx17
    temurin-jre-bin-17
    maven
    gradle
    glib
  ];

  shellHook = ''

    export PATH="$PATH:${pkgs.maven}/bin"
    export JAVA_HOME="${pkgs.jdk17}/lib/openjdk"
    export PATH="$PATH:$JAVA_HOME/bin"
    export LD_LIBRARY_PATH="${pkgs.libGL}/lib:${pkgs.gtk3}/lib:${pkgs.glib.out}/lib:${pkgs.xorg.libXtst}/lib:$LD_LIBRARY_PATH"   
    export JAVAFX_PATH="${pkgs.openjfx17}/lib"

    echo 🔨 Java DevShell


  '';
}
