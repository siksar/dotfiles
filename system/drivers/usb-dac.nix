# USB DAC dongle'ları — WebHID EQ araçları için hidraw uaccess (systemd hidraw'a genel uaccess vermez).
{ ... }:

let
  # vid/pid KÜÇÜK harf: udev ATTR karşılaştırması dizesel.
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
  # Kiwi Ears AD1 Pro (31b2:0113). Boot'ta takılıysa powertop autosuspend'i geri yazar; sorun
  # olursa power.nix'teki power-tunables-restore listesine ekle.
  services.udev.extraRules = dacRules "31b2" "0113";
}
