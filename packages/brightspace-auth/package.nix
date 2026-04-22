{ buildFHSEnv
, brightspace-mcp-server
, writeShellScript
, nodejs
, ...
}:
# FHS wrapper around brightspace-mcp-server's `brightspace-auth` CLI.
#
# The auth CLI launches Playwright's downloaded Chromium, which is dynamically
# linked against libraries NixOS doesn't place at the standard /lib/... paths
# the binary expects (libglib, libnss, libgbm, libxshmfence, …). Running it
# inside an FHS userns gives those libs their expected home.
#
# The bundled server ships with --ignore-scripts (no Chromium in the Nix
# store), so the wrapper installs the Chromium version bundled Playwright
# demands into ~/.cache/ms-playwright on first run. The install is idempotent:
# a no-op when the expected build is already cached. This means re-auth works
# across Playwright version bumps without manual intervention.
let
  playwrightCli = "${brightspace-mcp-server}/lib/node_modules/brightspace-mcp-server/node_modules/playwright/cli.js";

  wrap = writeShellScript "brightspace-auth-wrap" ''
    set -e
    node ${playwrightCli} install chromium
    exec brightspace-auth "$@"
  '';
in
buildFHSEnv {
  name = "brightspace-auth";

  targetPkgs = pkgs: with pkgs; [
    brightspace-mcp-server
    nodejs

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

  runScript = wrap;

  meta = {
    description = "FHS-wrapped Brightspace auth CLI for NixOS";
    mainProgram = "brightspace-auth";
  };
}
