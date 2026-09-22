{ inputs }:
final: _prev:
let
  master = import inputs.nixpkgs-master {
    inherit (final.stdenv.hostPlatform) system;
    inherit (final) config;
  };
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    inherit (final) config;
  };
in
{
  # From nixpkgs-master (fast updating / want latest always)
  inherit (master)
    yaziPlugins
    ;

  # Pinned ahead of nixpkgs-master, which still ships 2.1.278; Opus 5.5 needs
  # 2.1.280+. The package takes its version and per-platform checksums straight
  # from this manifest, which is the same file upstream's update.sh fetches:
  #   curl -fsSL https://downloads.claude.ai/claude-code-releases/latest
  #   curl -fsSL https://downloads.claude.ai/claude-code-releases/$VERSION/manifest.zst.json
  # Drop the override and restore the plain inherit once master catches up.
  claude-code = master.claude-code.override {
    manifest = builtins.fromJSON (builtins.readFile ./claude-code-manifest.json);
  };

  # From nixpkgs-unstable
  inherit (unstable)
    # Misc
    _1password-gui
    ;
}
