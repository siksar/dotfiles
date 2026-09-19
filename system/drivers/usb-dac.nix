# USB DAC/amp dongle'ları — hidraw erişim izni.
#
# NEDEN VAR: Bu dongle'ların ekolayzer/filtre ayarları ses akışında değil,
# cihazın kendi firmware'inde yaşıyor ve oraya yalnız HID rapor kanalından
# yazılıyor (ALSA/PipeWire bu kanalı hiç görmez). Üreticinin aracı tarayıcıda
# WebHID ile koşuyor, yani /dev/hidraw* düğümünü Chromium'un açabilmesi gerek.
#
# systemd'nin 70-uaccess.rules'u hidraw'a GENEL uaccess vermez — yalnız
# adlandırılmış birkaç sınıfa (FIDO token vb.). Etiketsiz kalan düğüm
# crw------- root:root doğar; tarayıcı cihazı seçici penceresinde USB
# descriptor'ından görür, ama açmaya çalışınca EACCES alır ve bunu
# "device not connected" diye raporlar. Ölçüm (12 Eyl 2026, Kiwi AD1 Pro):
#   getfacl /dev/hidraw0 → user::rw- group::--- other::---   (ACL YOK)
#   getfacl /dev/hidraw5 → user:zixar:rw- de VAR             (uaccess işlemiş)
# Fark izin katmanında; tarayıcı tarafında değil.
{ ... }:

let
  # Kural üreten yardımcı — cihaz başına üç satır, elle tekrar etmemek için.
  # vid/pid KÜÇÜK harf: udev ATTR karşılaştırması dizesel, sysfs "31b2" yazar,
  # "31B2" yazan kural sessizce hiç eşleşmez.
  dacRules = vid: pid: ''
    # hidraw düğümü — WebHID'in açtığı dosya. ATTRS{} (ATTR{} değil): hidraw
    # düğümünün kendi idVendor'ı yoktur, değer üst USB cihazından miras alınır.
    # uaccess = oturumu açık kullanıcıya ACL; MODE/GROUP yalnız yedek katman
    # (logind oturumu görmezse, ör. uzak oturum/servis). 0666 yerine 0660+users:
    # tek kullanıcılı makinede erişim aynı, dünyaya açık düğüm bırakmıyor.
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="${vid}", ATTRS{idProduct}=="${pid}", TAG+="uaccess", MODE="0660", GROUP="users"

    # USB cihaz düğümünün kendisi — tarayıcının cihazı numaralandırıp
    # seçiciye koyabilmesi (WebUSB yolu) ve çekirdek arayüzünü çözmesi için.
    SUBSYSTEM=="usb", ATTR{idVendor}=="${vid}", ATTR{idProduct}=="${pid}", TAG+="uaccess", MODE="0660", GROUP="users"

    # Autosuspend kapalı: USB ses cihazı askıya alınınca HID arayüzü de
    # uyur, uyanma gecikmesi rapor alışverişini zaman aşımına düşürebilir.
    # Idle bütçesine (4,28 W) etkisi yok — kural yalnız cihaz TAKILIYKEN
    # uygulanır, dongle çıkınca geriye hiçbir şey kalmaz; yoklama/timer yok.
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${vid}", ATTR{idProduct}=="${pid}", ATTR{power/control}="on"
  '';
in
{
  # Kiwi Ears AD1 Pro (31b2:0113) — equalizer.kiwiears.com WebHID aracı.
  #
  # SINIR (12 Eyl 2026): powertop --auto-tune HER USB cihazının power/control'ünü
  # "auto"ya çeker ve boot'ta bizim kuralımızdan SONRA koşar (gerekçe ve ölçüm:
  # system/kernel/power.nix). Dongle hot-plug olduğu için pratikte kurtuluyor —
  # takıldığı anda yeniden numaralandırılıyor ve kural tazeden işliyor. Ama
  # BOOT SIRASINDA TAKILI bırakılırsa powertop "auto"yu geri yazar. O senaryoda
  # ses/HID kopması görülürse çözüm 31b2:0113'ü power.nix'teki
  # power-tunables-restore case listesine eklemek; izin (uaccess) tarafı bundan
  # etkilenmez, yalnız autosuspend etkilenir.
  services.udev.extraRules = dacRules "31b2" "0113";
}
