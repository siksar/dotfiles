{ config, pkgs, ... }:
let
  themeSyncScript = pkgs.writeShellScriptBin "theme-sync" ''
    THEME_DIR="$HOME/.config/starship/themes"
    CURRENT_CONFIG="$HOME/.config/starship/current.toml"
    
    # Kullanım yardımı
    if [ -z "$1" ]; then
      echo "Noctalia Starship Theme Syncer"
      echo "Usage: theme-sync <theme-name>"
      echo ""
      echo "Available themes:"
      ls "$THEME_DIR" | sed 's/\.toml//g' | sed 's/^/  - /'
      echo ""
      echo "Special options:"
      echo "  - auto   : Try to detect Noctalia theme (experimental)"
      exit 1
    fi
    
    TARGET_THEME="$1"
    
    # Auto detection (Basit eşleştirme)
    if [ "$TARGET_THEME" == "auto" ]; then
      # Noctalia settings.json kontrol et
      if [ -f "$HOME/.config/noctalia/settings.json" ]; then
        # jq varsa kullan, yoksa grep ile basit çözüm
        if command -v jq &> /dev/null; then
             # Bu kısım Noctalia config yapısına göre güncellenmeli
             # Şimdilik placeholder
             echo "Auto detection not fully implemented yet."
             exit 1
        else
             echo "jq tool required for auto detection."
             exit 1
        fi
      else
        echo "Noctalia settings not found."
        exit 1
      fi
    fi
    
    SOURCE_FILE="$THEME_DIR/$TARGET_THEME.toml"
    
    if [ -f "$SOURCE_FILE" ]; then
      # Nix store read-only olduğu için cp --remove-destination kullanıyoruz
      # veya direkt üzerine yazıyoruz (cat ile) -> ama permission denied olabilir symlink ise.
      # current.toml symlink olmamalı, gerçek dosya olmalı.
      
      cp -f "$SOURCE_FILE" "$CURRENT_CONFIG"
      chmod +w "$CURRENT_CONFIG" # Yazılabilir yap
      
      echo "✅ Starship theme set to: $TARGET_THEME"
      echo "Opening a new terminal to see changes..."
    else
      echo "❌ Theme not found: $TARGET_THEME"
      echo "Path checked: $SOURCE_FILE"
      exit 1
    fi
  '';
in
{
  home.packages = [ themeSyncScript ];
}
