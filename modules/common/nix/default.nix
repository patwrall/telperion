{ config
, inputs
, lib
, pkgs
, self
, host
, ...
}:
let
  inherit (lib.telperion) mkBoolOpt mkOpt;

  cfg = config.telperion.nix;
in
{
  options.telperion.nix = {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt lib.types.package pkgs.nixVersions.latest "Which nix package to use.";
  };

  config = lib.mkIf cfg.enable {
    # faster rebuilding
    documentation = {
      doc.enable = false;
      info.enable = false;
      man.enable = lib.mkDefault true;
    };

    environment = {
      etc = {
        # set channels (backwards compatibility)
        "nix/flake-channels/system".source = self;
        "nix/flake-channels/nixpkgs".source = inputs.nixpkgs;
        "nix/flake-channels/home-manager".source = inputs.home-manager;
      }
      # preserve current flake in /etc
      // lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        "nixos".source = self;
      }
      // lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        "nix-darwin".source = self;
      };

      systemPackages = with pkgs; [
        # FIXME: broken pkg
        # cachix
        git
        nix-prefetch-git
      ];
    };

    # Shared config options
    # Check corresponding nixos/nix-darwin imported module
    nix =
      let
        users = [
          "root"
          "@wheel"
          "nix-builder"
          config.telperion.user.name
        ];
      in
      {
        inherit (cfg) package;

        buildMachines =
          let
            sshUser = "telperion";
            # TODO: update when ssh-ng isn't so slow
            # protocol = if pkgs.stdenv.hostPlatform.isLinux then "ssh-ng" else "ssh";
            protocol = "ssh";
            supportedFeatures = [
              "benchmark"
              "big-parallel"
              "nixos-test"
            ];
          in
          # Linux builders
          lib.optionals config.telperion.security.sops.enable [ ];

        checkConfig = true;
        distributedBuilds = true;
        gc.automatic = true;

        # This will additionally add your inputs to the system's legacy channels
        # Making legacy nix commands consistent as well
        # NOTE: We link inputs here
        nixPath = [ "/etc/nix/inputs" ];
        optimise.automatic = true;

        # pin the registry to avoid downloading and evaluating a new nixpkgs version every time
        # this will add each flake input as a registry to make nix3 commands consistent with your flake
        registry = lib.pipe inputs [
          (lib.filterAttrs (_: lib.isType "flake"))
          (lib.mapAttrs (_: flake: { inherit flake; }))
          (
            x:
            x
            // {
              nixpkgs.flake =
                if pkgs.stdenv.hostPlatform.isLinux then inputs.nixpkgs else inputs.nixpkgs-unstable;
            }
          )
          (x: if pkgs.stdenv.hostPlatform.isDarwin then lib.removeAttrs x [ "nixpkgs-unstable" ] else x)
        ];

        settings = {
          allowed-users = users;
          auto-optimise-store = pkgs.stdenv.hostPlatform.isLinux;
          builders-use-substitutes = true;
          download-buffer-size = 500000000;
          experimental-features = [
            "nix-command"
            "flakes"
            "ca-derivations"
            "auto-allocate-uids"
            "pipe-operators"
            "dynamic-derivations"
          ];
          # Prevent builds failing just because we can't contact a substituter
          fallback = true;
          flake-registry = "/etc/nix/registry.json";
          http-connections = 0;
          keep-derivations = true;
          keep-going = true;
          keep-outputs = true;
          log-lines = 50;
          preallocate-contents = true;
          sandbox = true;
          trusted-users = users;
          warn-dirty = false;

          allowed-impure-host-deps = [
            # Only wanted to add this for darwin from nixos
            # But, apparently using option wipes out all the other in the default list
            "/bin/sh"
            "/dev/random"
            "/dev/urandom"
            "/dev/zero"
            "/usr/bin/ditto"
            "/usr/lib/libSystem.B.dylib"
            "/usr/lib/libc.dylib"
            "/usr/lib/system/libunc.dylib"
          ];

          substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
            "https://nixpkgs-unfree.cachix.org"
            "https://numtide.cachix.org"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "nixpkgs-unfree.cachix.org-1:hqvoInulhbV4nJ9yJOEr+4wxhDV4xq2d1DK7S6Nj6rs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
          ];

          use-xdg-base-directories = true;
        };
      };
  };
}
