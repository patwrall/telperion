{ lib
, stdenvNoCC
, fetchFromGitHub
, ...
}:
# Unlike the discord plugin, `figma` is not vendored in claude-plugins-official:
# the marketplace manifest points at an external repo. Pin the same rev the
# manifest pins so we track what `claude plugin install` would have fetched.
stdenvNoCC.mkDerivation {
  pname = "claude-figma-plugin";
  version = "2.2.120";

  src = fetchFromGitHub {
    owner = "figma";
    repo = "mcp-server-guide";
    rev = "172920731eedf414e9b22ae60017d9a5b6c9f81f";
    hash = "sha256-Ri3XjKiECFjZiCrEF5zCAjfDoSB4j9k2AuJtM1UQKes=";
  };

  dontConfigure = true;
  dontBuild = true;

  # Pure content: skills plus a remote HTTP MCP server (mcp.figma.com), so
  # there is nothing to build and no node_modules to pre-fetch.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r . $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Claude Code Figma plugin — Figma MCP server and workflow skills";
    homepage = "https://github.com/figma/mcp-server-guide";
    # Upstream ships no LICENSE file; left unset rather than guessed.
    platforms = platforms.unix;
  };
}
