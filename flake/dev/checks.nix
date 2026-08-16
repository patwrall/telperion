{ inputs
, lib
, ...
}:
{
  imports = lib.optional (inputs.git-hooks-nix ? flakeModule) inputs.git-hooks-nix.flakeModule;

  perSystem =
    { pkgs, ... }:
    {
      pre-commit = lib.mkIf (inputs.git-hooks-nix ? flakeModule) {
        check.enable = false;

        settings.hooks = {
          actionlint.enable = true;
          clang-tidy.enable = true;
          deadnix = {
            enable = true;

            settings = {
              edit = true;
            };
          };
          eslint = {
            enable = true;
            package = pkgs.eslint_d;
          };
          luacheck.enable = true;
          # pre-commit-hook-ensure-sops.enable = true;
          statix.enable = true;
          treefmt.enable = true;
          typos = {
            enable = true;
            excludes = [ "generated/*" ];
            # snd_hda_intel is a kernel module name, not "had". Scoped to the
            # identifier so a genuine hda/had typo in prose still trips.
            settings.configuration = ''
              [default.extend-identifiers]
              snd_hda_intel = "snd_hda_intel"
            '';
          };
        };
      };

      checks = {
        # TODO:
        # Custom checks can go here
        # nix-syntax = pkgs.runCommand "check-nix-syntax" { } ''
        #   find ${./../..} -name "*.nix" -exec ${pkgs.nix}/bin/nix-instantiate --parse {} \; > /dev/null
        #   touch $out
        # '';
      };
    };
}
