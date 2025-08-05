# My NixOS Hyprland Flake Configuration

This repo contains my personal NixOS configuration, built as a flake.
It is designed to be a lightweight, modular, and reproducible system centered
around the Hyprland Wayland Compositor.

## Directory Structure

- `hosts/`: Contains machine-specific configurations.
- `modules/`: Contains reusable, single-purpose modules for the core system, such as audio.nix, network.nix, and security.nix.
- `home/`: Contains all user-specific configurations managed by Home Manager, organized into logical categories like gui, tui, and wm.
- `profiles/`: Contains top-level profiles that orchestrate which drivers are enabled/disabled for a given machine's role (e.g., vm).
