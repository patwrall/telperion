{ ...
}:
{
  mkcd = ''
    if test (count $argv) -ne 1
      echo "Usage: mkcd <directory>"
      return 1
    end
    mkdir -p $argv[1] && cd $argv[1]
  '';

  extract = ''
    if test (count $argv) -ne 1
      echo "Usage: extract <file>
      return 1
    end

    set file $argv[1]

    if not test -f $file
      echo "Error: 'file' is not a valid file"
      return 1
    end

    switch file
      case "*.tar.bz2"
        tar xjf $file
      case "*.tar.gz"
        tar xzf $file
      case "*.bz2"
        bunzip2 $file
      case "*.rar"
        unrar x $file
      case "*.gz"
        gunzip $file
      case "*.tbz2"
        tar xjf $file
      case "*.tgz"
        tar xzf $file
      case "*.zip"
        unzip $file
      case "*.Z"
        uncompress $file
      case "*.7z"
        7z x $file
      case "*"
        echo "Error: '$file' cannot be extracted or unsupported"
    end
  '';

  ff = ''
    find . -type d -iname "$argv*" 2>/dev/null
  '';

  fzf-file = ''
    fzf --preview 'bat --style=numbers --color always {}'
  '';

  backup = ''
    if test (count $argv) -ne 1
      echo "Usage: backup <file>"
      return 1
    end
    cp $argv[1] $argv[1].bak.(date +%Y%m%d_%H%M%S)
  '';

  du-here = ''
    du -h --max-depth=1 . | sort -hr
  '';

  killall-fuzzy = ''
    if test (count $argv) -ne 1
      echo "Usage: killall-fuzzy <process>"
      return 1
    end
    ps aux | grep $argv[1] | grep -v grep | awk '{print $2}' | xargs -r kill
  '';
}
