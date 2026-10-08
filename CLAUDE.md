Tek host `nixos` (AERO X16 EG61H), kullanıcı `zixar`. Yorum ve commit mesajları Türkçe. Ağaç ve donanım: README.md.

- `system/` + `usr/` NixOS modülü, `home/` HM modülü: birbirini import edemez; ortak olan `lib/`'de (`{ pkgs }:` fonksiyonu).
- Flake yalnız git'in izlediği dosyaları görür: yeni dosyayı eval'den önce `git add`.
- `''…''` içindeki `#` script metnidir, hash'e girer (wmi.nix, openrgb.nix, ryzen-smu.nix'te pahalı yeniden derleme).
- `nixfmt`'i ağaç genelinde çalıştırma (hizalı yorumları bozar).
- Davranışsal olmayan değişikliği (taşıma, yorum) drvPath öncesi/sonrası eşitliğiyle kanıtla.
- `Documentation/` eski ölçüm defterleri: tarihçe, bağlayıcı değil; yalnız gerekince oku.
