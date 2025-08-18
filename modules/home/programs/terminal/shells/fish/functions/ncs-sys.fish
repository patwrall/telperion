if test -z "$argv[1]"
    echo "Usage: ncs-sys <hostname>"
    return 1
end
if nix build ".#nixosConfigurations.$argv[1].config.system.build.toplevel" --no-link
    nix path-info --recursive --closure-size --human-readable (nix eval --raw ".#nixosConfigurations.$argv[1].config.system.build.toplevel.outPath") | tail -1
end
