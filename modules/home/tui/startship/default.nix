{ lib
, ...
}:
{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = lib.concatStrings [
        "($nix_shell"
        "$container"
        "$fill"
        "$git_metrics"
        "\n)"
        "$cmd_duration\n"
        "$hostname\n"
        "$localip\n"
        "$shlvl\n"
        "$shell\n"
        "$env_var\n"
        "$jobs\n"
        "$sudo\n"
        "$username\n"
        "$character"
      ];

      right_format = lib.concatStrings [
        "$singularity\n"
        "$kubernetes\n"
        "$directory\n"
        "$vcsh\n"
        "$fossil_branch\n"
        "$git_branch\n"
        "$git_commit\n"
        "$git_state\n"
        "$git_status\n"
        "$hg_branch\n"
        "$pijul_channel\n"
        "$docker_context\n"
        "$package\n"
        "$c\n"
        "$cmake\n"
        "$cobol\n"
        "$daml\n"
        "$dart\n"
        "$deno\n"
        "$dotnet\n"
        "$elixir\n"
        "$elm\n"
        "$erlang\n"
        "$fennel\n"
        "$golang\n"
        "$guix_shell\n"
        "$haskell\n"
        "$haxe\n"
        "$helm\n"
        "$java\n"
        "$julia\n"
        "$kotlin\n"
        "$gradle\n"
        "$lua\n"
        "$nim\n"
        "$nodejs\n"
        "$ocaml\n"
        "$opa\n"
        "$perl\n"
        "$php\n"
        "$pulumi\n"
        "$purescript\n"
        "$python\n"
        "$raku\n"
        "$rlang\n"
        "$red\n"
        "$ruby\n"
        "$rust\n"
        "$scala\n"
        "$solidity\n"
        "$swift\n"
        "$terraform\n"
        "$vlang\n"
        "$vagrant\n"
        "$zig\n"
        "$buf\n"
        "$conda\n"
        "$meson\n"
        "$spack\n"
        "$memory_usage\n"
        "$aws\n"
        "$gcloud\n"
        "$openstack\n"
        "$azure\n"
        "$crystal\n"
        "$custom\n"
        "$status\n"
        "$os\n"
        "$battery\n"
        "$time"
      ];

      fill = {
        symbol = " ";
      };

      character = {
        format = "$symbol ";
        success_symbol = "[◎](bold italic bright-yellow)";
        error_symbol = "[○](italic purple)";
        vimcmd_symbol = "[■](italic dimmed green)";
        vimcmd_replace_one_symbol = "◌";
        vimcmd_replace_symbol = "□";
        vimcmd_visual_symbol = "▼";
      };

      directory = {
        home_symbol = "⌂";
        truncation_length = 2;
        truncation_symbol = "□ ";
        read_only = " ◈";
        use_os_path_sep = true;
        style = "italic blue";
        format = "[ $path ] ($style) [ $read_only ] ($read_only_style)";
        repo_root_style = "bold blue";
        repo_root_format = "[ $before_root_path ] ($before_repo_root_style) [ $repo_root ] ($repo_root_style) [ $path ] ($style) [ $read_only ] ($read_only_style) [ △ ] (bold bright-blue)";
      };
    };
  };
}

