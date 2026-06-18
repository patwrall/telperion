{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, jre_headless
, ...
}:
stdenvNoCC.mkDerivation {
  pname = "discord-mcp-server";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/SaseQ/discord-mcp/releases/download/v1.0.0/discord-mcp-1.0.0.jar";
    hash = "sha256-QbJhyvDL86pWWdWbDUi4YEtXLMfOsQp1rKbIbI2PEAQ=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/discord-mcp-server}
    cp $src $out/share/discord-mcp-server/discord-mcp.jar
    makeWrapper ${lib.getExe jre_headless} $out/bin/discord-mcp-server \
      --add-flags "-jar $out/share/discord-mcp-server/discord-mcp.jar"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Discord MCP server — lets AI assistants manage Discord servers via JDA";
    homepage = "https://github.com/SaseQ/discord-mcp";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "discord-mcp-server";
    platforms = platforms.unix;
  };
}
