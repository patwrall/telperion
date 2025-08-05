{ lib
, ...
}:

{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      continuation_prompt = "[▸▹ ](dimmed white)";

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
        "$singularity"
        "$kubernetes"
        "$directory"
        "$vcsh"
        "$fossil_branch"
        "$git_branch"
        "$git_commit"
        "$git_state"
        "$git_status"
        "$hg_branch"
        "$pijul_channel"
        "$docker_context"
        "$package"
        "$c"
        "$cmake"
        "$cobol"
        "$daml"
        "$dart"
        "$deno"
        "$dotnet"
        "$elixir"
        "$elm"
        "$erlang"
        "$fennel"
        "$golang"
        "$guix_shell"
        "$haskell"
        "$haxe"
        "$helm"
        "$java"
        "$julia"
        "$kotlin"
        "$gradle"
        "$lua"
        "$nim"
        "$nodejs"
        "$ocaml"
        "$opa"
        "$perl"
        "$php"
        "$pulumi"
        "$purescript"
        "$python"
        "$raku"
        "$rlang"
        "$red"
        "$ruby"
        "$rust"
        "$scala"
        "$solidity"
        "$swift"
        "$terraform"
        "$vlang"
        "$vagrant"
        "$zig"
        "$buf"
        "$conda"
        "$meson"
        "$spack"
        "$memory_usage"
        "$aws"
        "$gcloud"
        "$openstack"
        "$azure"
        "$crystal"
        "$custom"
        "$status"
        "$os"
        "$battery"
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

      env_var.VIMSHELL =
        let
          env_value = "$env_value";
          style = "green italic";
        in
        {
          format = "[${env_value}](${style})";
          inherit style;
        };

      sudo = {
        format = "[$symbol]($style)";
        style = "bold italic bright-purple";
        symbol = " ";
        disabled = false;
      };

      username = {
        style_user = "bright-yellow bold italic";
        style_root = "purple bold italic";
        format = "[ $user]($style) ";
        disabled = false;
        show_always = false;
      };

      directory = {
        home_symbol = "";
        truncation_length = 2;
        truncation_symbol = "… ";
        read_only = " ";
        use_os_path_sep = true;
        style = "italic blue";
        format = "[$path]($style)[$read_only]($read_only_style)";
        repo_root_style = "bold blue";
        repo_root_format = "[$before_root_path]($before_repo_root_style)[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style)[ △](bold bright-blue)";
      };

      cmd_duration = {
        min_time = 0;
        format = "[ $duration ](italic white)";
      };

      jobs = {
        format = "[$symbol$number]($style) ";
        style = "white";
        symbol = "[▶](blue italic)";
      };

      localip = {
        ssh_only = true;
        format = " [$localipv4](bold magenta)";
        disabled = false;
      };

      time = {
        disabled = false;
        format = "[  $time]($style)";
        time_format = "%R";
        utc_time_offset = "local";
        style = "italic dimmed white";
      };

      battery = {
        format = "[ $percentage $symbol]($style)";
        full_symbol = "";
        charging_symbol = "[](italic bold green)";
        discharging_symbol = "";
        unknown_symbol = "";
        empty_symbol = "";
        display = [
          {
            threshold = 20;
            style = "italic bold red";
          }
          {
            threshold = 60;
            style = "italic dimmed bright-purple";
          }
          {
            threshold = 70;
            style = "italic dimmed yellow";
          }
        ];
      };

      git_branch = {
        format = " [$branch(:$remote_branch)]($style)";
        symbol = " ";
        style = "italic bright-blue";
        truncation_symbol = "⋯";
        truncation_length = 11;
        ignore_branches = [ "main" "master" ];
        only_attached = true;
      };

      git_metrics = {
        format = "([$added]($added_style))([$deleted]($deleted_style))";
        added_style = "italic dimmed green";
        deleted_style = "italic dimmed red";
        ignore_submodules = true;
        disabled = false;
      };

      git_status = {
        style = "bold italic bright-blue";
        format = "([⎪$ahead_behind$staged$modified$untracked$renamed$deleted$conflicted$stashed⎥]($style))";
        conflicted = "[](italic bright-magenta)";
        ahead = "[ [$count](bold white)│](italic green)";
        behind = "[ [$count](bold white)│](italic red)";
        diverged = "[ │[$ahead_count](regular white)││[$behind_count](regular white)│](italic bright-magenta)";
        untracked = "[](italic bright-yellow)";
        stashed = "[](italic white)";
        modified = "[](italic yellow)";
        staged = "[▪┤[$count](bold white)│](italic bright-cyan)";
        renamed = "[◎◦](italic bright-blue)";
        deleted = "[✕](italic red)";
      };

      deno = {
        format = " [deno](italic) [ $version](green bold)";
        version_format = "$version";
      };

      lua =
        let
          luaSymbol = "⨀ ";
        in
        {
          format = " [lua](italic) [${luaSymbol}$version]($style)";
          version_format = "$version";
          symbol = luaSymbol;
          style = "bold bright-yellow";
        };

      nodejs = {
        format = " [node](italic) [ ($version)](bold bright-green)";
        version_format = "$version";
        detect_files = [ "package-lock.json" "yarn.lock" ];
        detect_folders = [ "node_modules" ];
        detect_extensions = [ ];
      };

      python =
        let
          pythonSymbol = " ";
        in
        {
          format = " [py](italic) [${pythonSymbol}$version]($style)";
          symbol = pythonSymbol;
          version_format = "$version";
          style = "bold bright-yellow";
        };

      ruby = {
        format = " [rb](italic) [ $version]($style)";
        symbol = " ";
        version_format = "$version";
        style = "bold red";
      };

      rust = {
        format = " [rs](italic) [ $version]($style)";
        symbol = " ";
        version_format = "$version";
        style = "bold red";
      };

      package = {
        format = " [pkg](italic dimmed) [ $version]($style)";
        version_format = "$version";
        symbol = " ";
        style = "dimmed yellow italic bold";
      };

      swift = {
        format = " [sw](italic) [ $version]($style)";
        symbol = " ";
        style = "bold bright-red";
        version_format = "$version";
      };

      aws = {
        disabled = true;
        format = " [aws](italic) [ $profile $region]($style)";
        style = "bold blue";
        symbol = " ";
      };

      buf = {
        symbol = "■ ";
        format = " [buf](italic) [$symbol $version $buf_version]($style)";
      };

      c = {
        symbol = " ";
        format = " [$symbol($version(-$name))]($style)";
      };

      conda = {
        symbol = "◯ ";
        format = " conda [$symbol$environment]($style)";
      };

      dart = {
        symbol = " ";
        format = " dart [$symbol($version )]($style)";
      };

      docker_context = {
        symbol = " ";
        format = " docker [$symbol$context]($style)";
      };

      elixir = {
        symbol = " ";
        format = " exs [$symbol $version OTP $otp_version ]($style)";
      };

      elm = {
        symbol = " ";
        format = " elm [$symbol($version )]($style)";
      };

      golang = {
        symbol = "󰟓 ";
        format = " go [$symbol($version )]($style)";
      };

      haskell = {
        symbol = " ";
        format = " hs [$symbol($version )]($style)";
      };

      java = {
        symbol = " ";
        format = " java [$symbol($version )]($style)";
      };

      julia = {
        symbol = " ";
        format = " jl [$symbol($version )]($style)";
      };

      memory_usage = {
        symbol = " ";
        format = " mem [$ram( $swap)]($style)";
      };

      nim = {
        symbol = " ";
        format = " nim [$symbol($version )]($style)";
      };

      nix_shell =
        let
          nixSymbol = "󱄅";
        in
        {
          style = "bold italic dimmed blue";
          symbol = nixSymbol;
          format = "[${nixSymbol} nix⎪$state⎪]($style) [$name](italic dimmed white)";
          impure_msg = "[⌽](bold dimmed red)";
          pure_msg = "[⌾](bold dimmed green)";
          unknown_msg = "[◌](bold dimmed yellow)";
        };

      spack = {
        symbol = " ";
        format = " spack [$symbol$environment]($style)";
      };
    };
  };
}
