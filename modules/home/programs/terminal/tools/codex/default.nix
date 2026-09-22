{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkForce;

  cfg = config.telperion.programs.terminal.tools.codex;
  mcpModuleEnabled = config.telperion.programs.terminal.tools.mcp.enable or false;
  aiTools = import (lib.getFile "modules/common/ai-tools") { inherit lib; };

  configPath = ".codex/config.toml";
  generatedConfig = config.home.file.${configPath}.source;
in
{
  options.telperion.programs.terminal.tools.codex = {
    enable = mkEnableOption "Codex CLI configuration";
  };

  config = mkIf cfg.enable {
    programs.codex = {
      enable = true;

      enableMcpIntegration = mkIf mcpModuleEnabled true;

      context = aiTools.base;
      skills = aiTools.codex.skillsDir;
    };

    # Codex persists directory-trust decisions by writing config.toml itself.
    # Home Manager's default symlink into /nix/store makes that write fail
    # ("config/batchWrite failed ... failed to persist config"), which aborts
    # the TUI on the trust prompt. Manage the file from activation instead so
    # it stays a real, writable file.
    home.file.${configPath}.enable = mkForce false;

    home.activation.codexWritableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CONFIG="$HOME/${configPath}"

      mkdir -p "$(dirname "$CONFIG")"

      # Drop a leftover read-only store symlink from a previous generation.
      if [ -L "$CONFIG" ]; then
        rm -f "$CONFIG"
      fi

      # Keep what Codex owns (trust lives in [projects.*]) and re-apply the
      # Nix-managed [mcp_servers.*] tables, whose store paths change on every
      # rebuild and would otherwise go stale.
      PRESERVED=""
      if [ -f "$CONFIG" ]; then
        # Full store path: activation runs with a minimal PATH that has no awk,
        # which failed the whole home-manager unit with exit 127.
        PRESERVED="$(${pkgs.gawk}/bin/awk '/^\[/ { skip = ($0 ~ /^\[mcp_servers/) } !skip' "$CONFIG")"
      fi

      {
        if [ -n "$PRESERVED" ]; then
          printf '%s\n' "$PRESERVED"
        fi
        cat ${generatedConfig}
      } > "$CONFIG.hm-new"

      mv "$CONFIG.hm-new" "$CONFIG"
      chmod 644 "$CONFIG"
    '';
  };
}
