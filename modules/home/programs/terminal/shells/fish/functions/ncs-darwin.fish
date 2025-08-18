if test -z "$argv[1]"
    echo "Usage: ncs-darwin <hostname>"
    return 1
end
if nix build ".#darwinConfigurations.$argv[1].config.system.build.toplevel" --no-link
    nix path-info --recursive --closure-size --human-readable (nix eval --raw ".#darwinConfigurations.$argv[1].config.system.build.toplevel.outPath") | tail -1
end
