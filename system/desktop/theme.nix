# Stylix — tema katmanı (system): renklerin TEK kaynağı.
# Palet + font + imleç buradan tüm hedeflere (GTK, ghostty, vscodium, vesktop,
# starship...) dağılır; palet değişimi = lib/theme.nix + rebuild.
# Taban değerler lib/theme.nix'te — standalone HM (nh home switch) ile ortak.
{ pkgs, ... }:

{
  stylix = import ../../lib/theme.nix { inherit pkgs; } // {
    # Özel Miasma limine teması korunur (system/init/limine.nix ile çakışmasın)
    targets.limine.enable = false;
    # Plymouth kullanılmıyor (boot optimizasyonunda kaldırıldı)
    targets.plymouth.enable = false;
  };
}
