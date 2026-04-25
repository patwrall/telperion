{ lib
, stdenvNoCC
, fetchFromGitHub
, bun
, cacert
, jq
, ...
}:
let
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "020446a4294f09d9c32e60bff0c4ae8fb39205cb";
    hash = "sha256-ywyOB23pJaOQHf2nPvis1fNqpNPVUM59upxETzl6KCw=";
  };

  pluginSrc = "${src}/external_plugins/discord";

  # FOD: pre-fetch node_modules from the upstream bun.lock so the plugin can
  # run from a read-only /nix/store path without `bun install` at startup.
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "claude-discord-plugin-deps";
    version = "0.0.4";
    src = pluginSrc;

    nativeBuildInputs = [ bun cacert ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      bun install --frozen-lockfile --ignore-scripts --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r node_modules $out/
      runHook postInstall
    '';

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-4xCGDUcyFcStyyF4TXRf6mPibiYttIehzcqByln/hrg=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "claude-discord-plugin";
  version = "0.0.4";
  src = pluginSrc;

  nativeBuildInputs = [ jq ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out/
    chmod -R u+w $out
    cp -r ${nodeModules}/node_modules $out/node_modules
    # Skip the runtime `bun install` — deps already populated above.
    jq '.scripts.start = "bun server.ts"' $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
    # Pin the MCP server command to an absolute bun path (PATH-independent)
    # and drop --shell=bun: combined with --cwd it makes `bun run` fail to
    # locate the start script ("Script not found 'start'").
    jq --arg bun ${lib.getExe bun} \
      '.mcpServers.discord.command = $bun
       | .mcpServers.discord.args = [.mcpServers.discord.args[] | select(. != "--shell=bun")]' \
      $out/.mcp.json > $out/.mcp.json.tmp
    mv $out/.mcp.json.tmp $out/.mcp.json
    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code Discord plugin (Anthropic) — repackaged with offline node_modules";
    homepage = "https://github.com/anthropics/claude-plugins-official/tree/main/external_plugins/discord";
    license = licenses.asl20;
    platforms = platforms.unix;
  };
}
