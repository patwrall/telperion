if test -z "$argv[1]"
    echo "Usage: ncs-home <username@hostname>"
    return 1
end
if nix build ".#homeConfigurations.$argv[1].activationPackage" --no-link
    nix path-info --recursive --closure-size --human-readable (nix eval --raw ".#homeConfigurations.$argv[1].activationPackage.outPath") | tail -1
end
