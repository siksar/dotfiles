# 🌌 Zixar's NixOS Dotfiles

Welcome to my personal NixOS configuration, featuring **Hyprland**, the **Noctalia Shell**, and a cohesive **Miasma** (Orange/Gold) theme.

## 📸 Overview

*   **OS:** NixOS (Unstable/Rolling)
*   **Window Manager:** Hyprland
*   **Desktop Shell:** [Noctalia](https://github.com/noctalia-dev/noctalia-shell)
*   **Terminal:** Kitty
*   **Editor:** Neovim & Helix
*   **Launcher:** Noctalia Shell / Tofi
*   **Theme:** Miasma (Orange/Gold Accents)

## 🛠️ Structure

This repository is organized for clarity and modularity:

```
~/dotfiles/
├── base/          # System-wide configurations (NixOS)
│   ├── modules/   # Hardware, Kernel, Boot, Network, etc.
│   └── configuration.nix
├── home/          # User-specific configurations (Home Manager)
│   ├── modules/   # Hyprland, Noctalia, Apps, etc.
│   └── home.nix
├── packages/      # Custom package definitions
└── flake.nix      # Entry point
```

## 🚀 Installation & Usage

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
    ```

2.  **Apply Configuration:**
    ```bash
    sudo nixos-rebuild switch --flake ~/dotfiles#nixos
    ```

3.  **Update Config:**
    After making changes to any file in `~/dotfiles`:
    ```bash
    sudo nixos-rebuild switch --flake ~/dotfiles#nixos
    ```

## ⌨️ Keybindings (Hyprland)

| Key Config | Action |
| :--- | :--- |
| **Super (Tap)** | Toggle **Control Center** |
| **Super + Tab** | Open **App Launcher** |
| **Super + Return** | Open Terminal (Kitty) |
| **Super + W** | Files/Config Menu |
| **Super + A** | **Cava** Audio Visualizer |
| **Super + V** | Browser (Zen) |
| **Super + D** | Apps Menu |
| **Super + Q** | Close Window |
| **Super + Z** | Emoji Picker |
| **Super + F** | Maximize Window |

## 🎨 Features
*   **Boot Animation:** Plymouth BGRT (OEM Logo integration).
*   **Noctalia Shell:** Fully customized bar and widgets.
*   **Gaming Ready:** Steam, Gamemode, Gamescope enabled.
*   **Optimization:** Custom kernel flags and NVMe power saving.

---
*Configured with ❤️ by Zixar*
