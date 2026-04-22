{ lib
, buildNpmPackage
, fetchFromGitHub
, nodejs
, ...
}:
buildNpmPackage {
  pname = "brightspace-mcp-server";
  version = "1.2.6-unstable-2026-04-22";

  src = fetchFromGitHub {
    owner = "RohanMuppa";
    repo = "brightspace-mcp-server";
    rev = "eb2f99cf12811e8ff7581bbe0af2bf4a4a08a2db";
    hash = "sha256-/zw5QRfyFYGZWGCenQMlf/a7R7i2bemlji1QA9d2yGg=";
  };

  patches = [ ./patches/pfw-idp.patch ];

  npmDepsHash = "sha256-rhDpzRElWE1CNeMgEbQ0vnsMDsIXwGflQOk23K1WBu4=";

  # Runtime uses the saved session in ~/.d2l-session — no browser needed.
  # The auth CLI is run separately in an FHS env when the session expires,
  # so skip the Playwright chromium download during build. npmFlags is passed
  # to every npm invocation (including `npm ci`), unlike npmInstallFlags which
  # only applies to the install phase.
  env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  npmFlags = [ "--ignore-scripts" ];

  inherit nodejs;

  meta = with lib; {
    description = "MCP server for Brightspace (D2L) — patched for non–West Lafayette Purdue campuses (PFW, PNW)";
    homepage = "https://github.com/RohanMuppa/brightspace-mcp-server";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "brightspace-mcp-server";
    platforms = platforms.unix;
  };
}
