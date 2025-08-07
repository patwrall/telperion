{ lib
, stdenv
, fetchFromGitHub
, coreutils
, xdg-terminal-exec
, libnotify
, nix-update-script
}:
stdenv.mkDerivation {
  pname = "app2unit";
  version = "0-unstable-2025-08-06";

  src = fetchFromGitHub {
    owner = "Vladimir-csp";
    repo = "app2unit";
    rev = "d951c2b277a32cd2c57659c363bee4872c989969";
    hash = "";
  };

  buildInputs = [
    coreutils
    xdg-terminal-exec
    libnotify
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp app2unit $out/bin
  '';

  passthru.updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };

  meta = {
    description = "A simple app launcher for X11 and Wayland";
    homepage = "https://github.com/Vladimir-csp/app2unit";
    mainProgram = "app2unit";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
  };
}
