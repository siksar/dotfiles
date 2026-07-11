# Stylix — taban tema katmanı (system)
# Renklerin asıl runtime motoru aktif kabuğun tema motorudur (ör. Caelestia CLI);
# Stylix font, imleç ve build-time varsayılan renkleri sağlar.
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
