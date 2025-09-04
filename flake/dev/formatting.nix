{ inputs
, lib
, ...
}:
{
  imports = lib.optional (inputs.treefmt-nix ? flakeModule) inputs.treefmt-nix.flakeModule;

  perSystem =
    { pkgs, ... }:
    {
      treefmt = lib.mkIf (inputs.treefmt-nix ? flakeModule) {
        flakeCheck = true;
        flakeFormatter = true;

        projectRootFile = "flake.nix";

        programs = {
          actionlint.enable = true;
          biome = {
            enable = true;
            settings.formatter.formatWithErrors = true;
          };
          clang-format.enable = true;
          deadnix = {
            enable = true;
            no-lambda-arg = true;
          };
          deno = {
            enable = true;
            # Using biome for these
            excludes = [
              "*.ts"
              "*.js"
              "*.json"
              "*.jsonc"
            ];
          };
          fantomas.enable = true;
          fish_indent.enable = true;
          gofmt.enable = true;
          isort.enable = true;
          nixfmt = {
            enable = true;
            package = pkgs.nixpkgs-fmt;
          };
          ruff-check.enable = true;
          ruff-format.enable = true;
          rustfmt.enable = true;
          shfmt = {
            enable = true;
            indent_size = 4;
          };
          statix.enable = true;
          stylua.enable = true;
          taplo.enable = true;
          yamlfmt.enable = true;
        };

        settings = {
          global.excludes = [
            "*.editorconfig"
            "*.envrc"
            "*.gitconfig"
            "*.git-blame-ignore-revs"
            "*.gitignore"
            "*.gitattributes"
            "*.luacheckrc"
            "*CODEOWNERS"
            "*LICENSE"
            "*flake.lock"
            "*.conf"
            "*.gif"
            "*.ico"
            "*.ini"
            "*.micro"
            "*.png"
            "*.svg"
            "*.tmux"
            "*/config"
            # TODO: formatters?
            "*.ac"
            "*.css" # Exclude CSS files from formatting since we use Nix template variables
            "*.csproj"
            "*.fsproj"
            "*.in"
            "*.kdl"
            "*.kvconfig"
            "*.rasi"
            "*.sln"
            "*.xml"
            "*.zsh"
            "*Makefile"
            "*makefile"

            # Unique files
            "lib/base64/ascii"
          ];

          formatter.ruff-format.options = [ "--isolated" ];
        };
      };
    };
}
