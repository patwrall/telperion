{ lib
, stdenvNoCC
, fetchFromGitHub
, jq
, ...
}:
# pstack ships only `.cursor-plugin/plugin.json`, so Claude Code does not see it
# as a plugin at all, and it belongs to no marketplace — registering it under a
# name Claude Code doesn't know fails with "Marketplace <name> not found".
#
# So this derivation builds a one-entry *marketplace* rather than a bare plugin:
#   $out/.claude-plugin/marketplace.json   the marketplace, named `backnotprop`
#   $out/pstack/                           the plugin, source "./pstack"
# The plugin source must be a marketplace-relative path; an absolute one is
# rejected ("source: Invalid input").
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "claude-pstack-plugin";
  # Kept in step with .cursor-plugin/plugin.json; installPhase asserts the match
  # so a rev bump that moves the version fails the build instead of silently
  # disagreeing with what `claude plugin list` reports.
  version = "0.15.2";

  src = fetchFromGitHub {
    owner = "backnotprop";
    repo = "pstack";
    rev = "157aae39a733135e93d8b5b19ff62c6a84b0ad56";
    hash = "sha256-zeDqjhLFSi/xTmRnp4DmsvZ2oiLMVeSQhKGhC+IUiS8=";
  };

  nativeBuildInputs = [ jq ];

  dontConfigure = true;
  dontBuild = true;

  # Pure content: 47 skills and 2 agents, no MCP server and nothing to compile.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/pstack/.claude-plugin $out/.claude-plugin
    cp -r . $out/pstack/
    chmod -R u+w $out/pstack

    upstreamVersion=$(jq -r .version $out/pstack/.cursor-plugin/plugin.json)
    if [ "$upstreamVersion" != "${finalAttrs.version}" ]; then
      echo "pstack version drifted: nix says ${finalAttrs.version}, upstream says $upstreamVersion" >&2
      exit 1
    fi

    # Claude Code discovers skills/ and agents/ by convention at the plugin
    # root, which pstack already lays out that way; it only needs the manifest.
    jq '{ name, description, version, author, homepage, license, keywords }' \
      $out/pstack/.cursor-plugin/plugin.json > $out/pstack/.claude-plugin/plugin.json

    jq -n --arg version "${finalAttrs.version}" '{
      name: "backnotprop",
      owner: { name: "backnotprop", url: "https://github.com/backnotprop" },
      plugins: [ {
        name: "pstack",
        description: "Rigorous agent workflows: poteto-mode, principles, and review skills",
        source: "./pstack",
        version: $version,
      } ],
    }' > $out/.claude-plugin/marketplace.json

    runHook postInstall
  '';

  meta = {
    description = "Claude Code plugin packaging of pstack — 47 agent skills and 2 agents";
    homepage = "https://github.com/backnotprop/pstack";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
