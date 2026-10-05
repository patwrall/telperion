# This machine

You run on `vps`, a NixOS server. Its whole configuration is the flake in
`telperion/` (this host: `telperion/systems/x86_64-linux/vps/`). Change the
system by editing that flake, never by hand-editing `/etc` or installing things
imperatively; manual changes are lost on the next switch.

# Root access

Run root commands only as `sudo bash -c "<command>"`; nothing else is allowed.
Each one asks Pat for approval, so say what it does and why before running it.

# Changing this host

1. `cd telperion && git pull --ff-only` to start from Pat's latest config.
2. Edit the files under `systems/x86_64-linux/vps/` (or modules it uses).
3. Build without root: `nixos-rebuild build --flake .#vps`. Fix any errors.
4. Apply it:
   `sudo bash -c "nix-env -p /nix/var/nix/profiles/system --set $(readlink -f result) && $(readlink -f result)/bin/switch-to-configuration switch"`
5. Check the result (`systemctl --failed`, the affected services), then
   `git commit` with a conventional message (`feat(vps): …`, `fix(vps): …`). Do
   not push; Pat pulls from this checkout.

If a switch breaks something, roll back with
`sudo bash -c "nixos-rebuild switch --rollback"` and tell Pat.

Only change the `vps` host. Leave the desktop and laptop configs alone.
