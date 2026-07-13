# Helix — ana editör (HM)
# LSP/tree-sitter/çoklu imleç/picker gömülü; plugin yönetimi yok.
# Tema Stylix'ten otomatik gelir (stylix.targets.helix), burada theme AYARLAMA.
#
# Hızlı rehber:
#   Space f  → dosya bul (fuzzy)        Space /  → projede metin ara (grep)
#   Space e  → dosya gezgini            Space b  → açık buffer'lar
#   Space s  → dosyadaki semboller      Space S  → projedeki semboller
#   gd       → tanıma git               gr       → referanslar (dosya:satır listesi)
#   Space k  → hover (dokümantasyon)    Space r  → yeniden adlandır
#   Ctrl-w v → dikey böl                Ctrl-w s → yatay böl
#   Ctrl-w h/j/k/l → bölmeler arası geçiş
{ pkgs, ... }:

{
  programs.helix = {
    enable = true;
    defaultEditor = true; # EDITOR=hx

    # LSP/formatter'lar Helix'in PATH'ine gömülür, sistemi kirletmez
    extraPackages = with pkgs; [
      # Nix
      nixd
      nixfmt-rfc-style
      # Shell
      bash-language-server
      shellcheck
      shfmt
      # Veri/dokümantasyon
      yaml-language-server           # + Kubernetes şemaları (aşağıda)
      vscode-langservers-extracted   # json/css/html
      marksman                       # markdown
      taplo                          # toml
      # Python
      basedpyright
      ruff
      # Rust / C / C++
      rust-analyzer
      clang-tools                    # clangd
      # Konteyner/K8s deklaratifleri
      dockerfile-language-server
      docker-compose-language-service
      helm-ls
    ];

    settings = {
      editor = {
        bufferline = "multiple";       # üstte açık dosya sekmeleri
        cursorline = true;
        color-modes = true;
        true-color = true;
        popup-border = "all";
        indent-guides.render = true;
        file-picker.hidden = false;    # gizli dosyaları da listele (.envrc vs.)
        end-of-line-diagnostics = "hint";
        inline-diagnostics.cursor-line = "warning"; # imleç satırında uyarıyı göm
        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };
        statusline.center = [ "diagnostics" "workspace-diagnostics" ];
        soft-wrap.enable = true;
      };
      keys.normal = {
        # Alışkanlık köprüsü: Ctrl-s kaydet
        C-s = ":write";
      };
    };

    languages = {
      language-server = {
        # nixd'yi BU flake'e bağla: option tamamlama + pkgs bilgisi + gd/gr
        nixd.config.nixd = {
          nixpkgs.expr = ''import (builtins.getFlake "/home/zixar/nixos-zixar").inputs.nixpkgs { }'';
          options = {
            nixos.expr = ''(builtins.getFlake "/home/zixar/nixos-zixar").nixosConfigurations.nixos.options'';
            home-manager.expr = ''(builtins.getFlake "/home/zixar/nixos-zixar").nixosConfigurations.nixos.options.home-manager.users.type.getSubOptions [ ]'';
          };
        };
        yaml-language-server.config.yaml = {
          schemaStore.enable = true; # schemastore.org: compose, GH Actions, vs.
          schemas.kubernetes = "{k8s,kubernetes,manifests}/**/*.{yaml,yml}";
        };
        basedpyright.config.basedpyright.analysis.typeCheckingMode = "standard";
      };

      language = [
        {
          name = "nix";
          language-servers = [ "nixd" ];
          formatter.command = "nixfmt";
          auto-format = false; # mevcut dosya stilini bozmasın; elle :fmt
        }
        {
          name = "python";
          language-servers = [ "basedpyright" "ruff" ];
        }
        {
          name = "bash";
          formatter = { command = "shfmt"; args = [ "-i" "2" "-" ]; };
        }
      ];
    };
  };
}
