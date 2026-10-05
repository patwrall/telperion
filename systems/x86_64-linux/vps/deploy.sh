#!/usr/bin/env bash
# Deploy the vps host from this machine. Refuses while Herm has commits on
# the VPS that aren't here yet, so a deploy never silently reverts its work.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
herm=pat@vps:/var/lib/hermes/workspace/telperion

git fetch -q "$herm" main
unpulled=$(git rev-list HEAD..FETCH_HEAD)
if [ -n "$unpulled" ]; then
    echo "Herm has commits you haven't pulled:"
    git log --oneline HEAD..FETCH_HEAD
    echo "Pull them first: git pull $herm main"
    exit 1
fi

exec nixos-rebuild switch --flake .#vps --target-host pat@vps --sudo --use-substitutes "$@"
