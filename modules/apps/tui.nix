# TUI/CLI ortamı — sway rice'ın parçası (vyrx-dev/dotfiles portu). Neovim
# config'i PORTLANMADI (mason NixOS'ta ayrı bir iş, docs/sway-rice.md'de not
# düşüldü) — sadece paket kurulu, varsayılan config.
{ config, lib, pkgs, ... }:

lib.mkIf config.rice.sway.enable {
  programs.tmux = {
    enable = true;
    prefix = "C-s";
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 1000000;
    mouse = true;
    terminal = "tmux-256color";
    plugins = with pkgs.tmuxPlugins; [ sensible vim-tmux-navigator ];
    extraConfig = ''
      set -g detach-on-destroy off
      set -g renumber-windows on
      set -g set-clipboard on
      set -g status-position top

      bind v split-window -h -c "#{pane_current_path}"
      bind s split-window -v -c "#{pane_current_path}"

      bind C-k display-popup -E "sessionX"
      bind C-p display-popup -E "sessionX ~/Projects"
      bind C-g run-shell "open-github"
      bind C-j run-shell "tmux-layout"
      bind g display-popup -E lazygit
    '';
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
  };

  # Renkler Stylix'ten (stylix.targets.zathura devre dışı bırakılmadı — bu
  # rice'a özel bir uygulama değil, GNOME/Hyprland'de de kullanılabilir).
  programs.zathura.enable = true;

  programs.btop.enable = true;
  programs.lazygit.enable = true;
  programs.neovim.enable = true;

  home.packages = with pkgs; [
    gh-dash
    (pkgs.writeShellApplication {
      name = "sessionX";
      runtimeInputs = [ pkgs.fzf pkgs.fd pkgs.tmux ];
      text = ''
        dirs=(~/Downloads ~/Documents ~/Git ~/Projects ~/nixos-zixar)
        [ $# -gt 0 ] && dirs=("$@")

        sel=$(fd . "''${dirs[@]}" --maxdepth 1 --type d 2>/dev/null | fzf) || exit 0
        [ -z "$sel" ] && exit 0
        name=$(basename "$sel" | tr . _)

        if ! tmux has-session -t "$name" 2>/dev/null; then
          tmux new-session -ds "$name" -c "$sel"
        fi
        if [ -n "''${TMUX:-}" ]; then
          tmux switch-client -t "$name"
        else
          tmux attach -t "$name"
        fi
      '';
    })
    (pkgs.writeShellApplication {
      name = "open-github";
      runtimeInputs = [ pkgs.git pkgs.xdg-utils ];
      text = ''
        url=$(git config --get remote.origin.url) || exit 0
        url=''${url/git@github.com:/https://github.com/}
        url=''${url%.git}
        xdg-open "$url"
      '';
    })
    (pkgs.writeShellApplication {
      name = "tmux-layout";
      runtimeInputs = [ pkgs.tmux ];
      text = ''
        tmux split-window -h -p 30
        tmux split-window -v -p 35
        tmux select-pane -t 0
      '';
    })
  ];
}
