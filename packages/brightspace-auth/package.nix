{ buildFHSEnv
, brightspace-mcp-server
, ...
}:
# FHS wrapper around brightspace-mcp-server's `brightspace-auth` CLI.
#
# The auth CLI launches Playwright's downloaded Chromium, which is dynamically
# linked against libraries NixOS doesn't place at the standard /lib/... paths
# the binary expects (libglib, libnss, libgbm, libxshmfence, …). Running it
# inside an FHS userns gives those libs their expected home.
#
# Re-running on session expiry is now a single command: `brightspace-auth`.
buildFHSEnv {
  name = "brightspace-auth";

  targetPkgs = pkgs: with pkgs; [
    brightspace-mcp-server

    # Playwright Chromium runtime deps.
    glib
    nss
    nspr
    atk
    at-spi2-atk
    at-spi2-core
    cups
    dbus
    libdrm
    gtk3
    pango
    cairo
    expat
    alsa-lib
    mesa
    libgbm
    libGL
    libxshmfence
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxrender
    libxcb
    libxkbcommon
    fontconfig
    freetype
    systemd
  ];

  runScript = "brightspace-auth";

  meta = {
    description = "FHS-wrapped Brightspace auth CLI for NixOS";
    mainProgram = "brightspace-auth";
  };
}
