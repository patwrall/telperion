{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkDefault;
  inherit (lib.telperion) enabled;

  cfg = config.telperion.suites.development;
in
{
  options.telperion.suites.development = {
    enable = lib.mkEnableOption "common development configuration";
    dockerEnable = lib.mkEnableOption "docker development configuration";
    goEnable = lib.mkEnableOption "go development configuration";
    kubernetesEnable = lib.mkEnableOption "kubernetes development configuration";
    nixEnable = lib.mkEnableOption "nix development configuration";
    sqlEnable = lib.mkEnableOption "sql development configuration";
  };

  config = mkIf cfg.enable {
    home = {
      packages =
        with pkgs;
        [
          jqp
          tree-sitter
          postman
        ]
        ++ lib.optionals cfg.dockerEnable [
          podman
          podman-tui
        ]
        ++ lib.optionals cfg.nixEnable [
          hydra-check
          nix-bisect
          nix-diff
          nix-fast-build
          nix-health
          nix-index
          nix-output-monitor
          nix-update
          nixpkgs-hammering
          nixpkgs-lint-community
          nixpkgs-review
          nurl
        ]
        ++ lib.optionals cfg.sqlEnable [
          dbeaver-bin
          mysql-workbench
        ];
    };

    programs = {
      nix-your-shell = mkDefault enabled;
    };

    telperion = {
      programs = {
        terminal = {
          editors = {
            neovim = {
              enable = mkDefault true;
              default = mkDefault true;
            };
          };

          tools = {
            act = mkDefault enabled;
            git-crypt = mkDefault enabled;
            go.enable = cfg.goEnable;
            k9s.enable = cfg.kubernetesEnable;
            lazydocker.enable = cfg.dockerEnable;
            lazygit = mkDefault enabled;
          };
        };
      };

    };
  };
}
