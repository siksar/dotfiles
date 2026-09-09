# İndirme yöneticisi (HM) — Varia: GTK4/libadwaita arayüz + aria2 motoru.
#
# NEDEN İNDİRME YÖNETİCİSİ: tarayıcı tek TCP bağlantısıyla indirir; TR'de
# operatör başına-bağlantı hız sınırı uyguladığı için hat dolmaz. aria2 aynı
# dosyayı parçalara bölüp paralel bağlantı açar (varsayılan 16'ya kadar) ve
# hattı gerçekten doyurur. Ters yön de aynı motorda: global hız sınırı
# (Ayarlar → "Speed limits") koyunca indirme, ev ağının geri kalanını aç
# bırakmaz. Kesinti sonrası devam (HTTP Range) tarayıcıdan farklı olarak
# gerçekten çalışır.
#
# NEDEN VARIA, Motrix/Persepolis DEĞİL (ölçüm, 19 Ağu 2026 — bu makinenin
# mevcut sistem kapanışına göre NET artış, ortak bağımlılıklar düşülmüş):
#   varia       +57  MiB  (15 store yolu)   ← seçilen
#   gopeed      +79  MiB
#   motrix      +280 MiB  ← Electron; sisteme İKİNCİ bir Chromium yığını
#   persepolis  +584 MiB  ← Qt + kendi python yığını
# Varia bu kadar ucuz çünkü GTK4/libadwaita/gstreamer zaten sistemde var
# (Stylix + Caelestia); yalnız aria2 + birkaç python modülü + yt-dlp ekliyor.
# Motrix'i eleme gerekçesi edfbb3c ile aynı: deezer-enhanced ikinci bir
# Chromium yığını taşıdığı için kaldırılmıştı, aynı bedeli geri almayalım.
# Ölçümü tekrarlamak istersen: paketin kapanış yollarını `nix path-info -r`
# ile alıp /run/current-system'inkiyle `comm -23` yap, farkın narSize'ını topla.
# TABANA DİKKAT: yukarıdaki rakamlar SİSTEM kapanışına göre. `hms` (standalone
# HM) çıktısı daha büyük bir artış gösterir — o profilin kendi tabanı ayrıdır ve
# python3.14 tabanı/yt-dlp orada yoktu. İkisi çelişmiyor, farklı taban ölçüyorlar.
#
# IDLE BÜTÇESİ (4.28 W) DOKUNULMADI: burada systemd unit YOK. aria2 daemon'ı
# uygulama açıldığında çocuk süreç olarak doğar, kapanınca ölür — boot'ta ya da
# boştayken çalışan hiçbir şey eklenmiyor. Bir gün "arka planda indirmeye devam
# etsin" istenirse o, sched.nix'teki tasarım kısıtını yeniden gözden geçirmeyi
# gerektirir; sessizce systemd.user servisi ekleme.
#
# TEMA: elle renk verilmiyor — libadwaita uygulaması, Stylix'in GTK hedefi
# (system/desktop/theme.nix) zaten boyuyor. dconf sistem genelinde açık
# (configuration.nix), GSettings şeması HM profilinden çözülüyor.
#
# YEREL AĞ tarafı bunun işi DEĞİL: cihazdan cihaza dosya paylaşımı
# system/net/localsend.nix'te (LocalSend, ikili adı `localsend_app`).
{ pkgs, ... }:

{
  # aria2'yi kendi kapanışında getirir (1.37.0) — ayrıca `aria2c` CLI'ı
  # PATH'e koymaz. Terminalden tek seferlik indirme istersen `aria2` paketini
  # ayrıca ekle (+5 MiB); şu an bilinçli olarak eklenmedi.
  # yt-dlp da kapanışta: video sitesi bağlantıları da bu arayüzden inebiliyor.
  home.packages = [ pkgs.varia ];
}
