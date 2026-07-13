# Stylix — tema katmanı (system): renklerin TEK kaynağı.
# Palet + font + imleç buradan tüm hedeflere (GTK/GNOME, ghostty, helix,
# vesktop, starship...) dağılır; palet değişimi = stylix-base.nix + rebuild.
# Taban değerler stylix-base.nix'te — standalone HM (nh home switch) ile ortak.
{ pkgs, ... }:

{
  stylix = import ./stylix-base.nix { inherit pkgs; } // {
    # Özel Miasma limine teması korunur (modules/boot/limine.nix ile çakışmasın)
    targets.limine.enable = false;
    # Plymouth kullanılmıyor (boot optimizasyonunda kaldırıldı)
    targets.plymouth.enable = false;
  };
}
