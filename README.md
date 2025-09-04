# Telperion NixOS Config

This repository holds my personal NixOS configuration, managed with Nix Flakes.
The goal is a reproducible and modular setup for my machines.

## Core Philosophy

This configuration is built around a few key principles:

- **Modularity**: The configuration is broken down into logical, reusable
  modules found in the `modules/` directory. This allows for easy composition of
  different features for different hosts. The structure is further organized
  into system-level (`nixos`), user-level (`home`), and shared (`common`)
  modules to maintain a clean separation of concerns.
- **Security**: Secure Boot is managed via `lanzaboote`, and secrets are handled
  at build time using `op-nix` for its direct integration with a 1Password
  vault, ensuring no sensitive data is stored in the repository.
- **Reproducibility**: Every aspect, from system packages to user dotfiles
  managed by Home Manager, is defined declaratively to ensure a consistent
  environment.

## Deployment

To deploy this configuration on a new NixOS installation:

1. **Clone this repository**

```bash
# Clone repo
git clone https://github.com/patwrall/telperion.git

cd telperion/
```

2. **Configure a new system and host** This repository separates machine
   configurations (`systems/`) from user configurations (`homes/`). To deploy to
   a new machine, create a new configuration file in the `systems/` directory
   that defines your hardware and a corresponding user profile in the `homes/`
   directory (See my profiles for reference).

3. **Build the system** Execute the build. The flake is configured to link the
   system's hostname (`systems/`) and apply the corresponding system and home
   configurations (`homes/`).

```bash
# Replace 'hostname' with the target system's configuration name
sudo nixos-rebuild switch --flake .#hostname
```

## Acknowledgements

This configuration draws significant inspiration (and things to copy) from the
work of others in the Nix community.

- [khaneliman/khanelinix](https://github.com/khaneliman/khanelinix) -Direct
  adaptation of structure (and excellent learning material)
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
