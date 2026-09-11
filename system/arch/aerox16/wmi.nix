# Gigabyte WMI/EC — KENDİ sürücümüz (aero_eg61h) + acpi_call ile ham EC yazımı.
# Fan modu, şarj limiti, 0xED perf profili, ACBT dGPU boost bütçesi.
# DSDT/EC sürümüne bağlı, elle tersine mühendislik: Documentation/aerox16/wmi-ec.md
# UYARI: 0x4B ve 0xF1-F3 EC tarafından geri yazılıyor — denemeyin (31 Tem).
#
# 7 EYL 2026 — `aorus-laptop` BIRAKILDI, yerine `aero_eg61h` geldi.
#
# Sürücü, servisler ve polkit kuralı artık `~/aero-eg61h`'deki modülden geliyor
# (aşağıdaki import). Bu dosyada kalan: Fn tuşu hwdb kuralı ve ölçüm defteri.
#
# NEDEN DEĞİŞTİ — üç ölçülmüş hata:
#   1. `pwm1`/`pwm2` yazılabilir sunuyordu, fan umursamıyordu (üç bağımsız kanıt).
#   2. `temp2`/`temp3` sunuyordu, ikisi de sabit sıfır (SKTC ölü kanal; tam yükte
#      CPU 91 °C iken bile 0).
#   3. `fan_mode` YANLIŞ BİLDİRİYORDU — ve yanlış YAZIYORDU. Ayrıntı aşağıda.
#
# 3. MADDE BU DOSYAYI DOĞRUDAN İLGİLENDİRİYOR (ölçüldü 7 Eyl, acpi_call ile
# bit bit): `aorus_laptop`, PECM+0x2C'nin b0/b1/b2'sini birbirini dışlayan bir
# grup olarak yönetiyor ama b3'ü (ADJF) desenin parçası SAYMIYOR; `fan_mode = 4`
# bir mod değil, "ADJF'yi kapat" işlemi. Sonuç ADJF'nin o anki durumuna bağlı ve
# dördünün de doğru çalıştığı bir durum YOK:
#
#   yazılan        ADJF=1 iken                    ADJF=0 iken
#   -------------  -----------------------------  -----------------------------
#   1 "sessiz"     0x09 = mod4          ✗          0x01 = quiet         ✓
#   2 "gaming"     0x0a = TANINMIYOR    ✗          0x02 = gaming        ✓
#   5 "turbo"      0x0c = turbo         ✓          0x04 = TANINMIYOR    ✗
#   4 "dengeli"    0x04 = TANINMIYOR    ✗          0x04 = TANINMIYOR    ✗
#
# İki somut kayıp: (a) bu makine AYLARDIR aşağıdaki servis `fan_mode = 1`
# ("sessiz") yazarken aslında mod 4'te (balanced) koşuyordu; (b) Süper+M döngüsü
# ilk adımda ("4") ADJF'yi sıfırlıyordu, ondan sonra hem döngünün "Turbo"su hem
# `game-perf`'in `fan_mode = 5`'i TANINMAYAN bir desene düşüyordu — yani oyun
# turbosu sessizce çalışmıyordu.
#
# Yeni sürücü deseni dört seçiciyle TAM yazıp yine dört seçiciyle GERİ OKUYOR;
# uyuşmazlıkta -EIO dönüyor. Bu yüzden varsayılan `balanced` — makinenin
# gerçekten koştuğu mod bu, ve `quiet` yazmak davranışı DEĞİŞTİRİRDİ.
#
# Geçiş planı ve tam ölçüm: ~/aero-eg61h/docs/nixos-gecis.md
{ inputs, ... }:

{
  imports = [ "${inputs.aero-eg61h}/nix/aero-eg61h.nix" ];

  hardware.aero-eg61h = {
    enable = true;

    # AC ve pilde aynı: `balanced` (PECM+0x2C = 0x09). Mod 4 sessiz gibi geç
    # başlıyor (54 °C) ama varsayılan gibi yükselebiliyor (%43 tavan).
    # Bu, makinenin aorus_laptop altında zaten koştuğu moddu — değiştirmiyoruz.
    fanMode.ac = "balanced";
    fanMode.battery = "balanced";

    # Şarj limiti %60 (pil-ömrü modu; yolculuk öncesi tam kapasite gerekiyorsa
    # 100 yap + rebuild). Sürücü yazımı GERİ OKUYUP doğruluyor; ayrıca kendi
    # uyanış kancası var (7 Eyl'de doğrulandı: "uyanis: ... korunmus, dokunulmadi").
    chargeLimit = 60;

    # ACBT (0x4C, ×8W): AC'de 80W → nvidia-powerd GPU tavanını 50→75W+ yapar;
    # pilde 0 (verim). gpu_boost (0x51) yazılMIYOR: bu DSDT'de 2=no-op, 3=dGPU eject!
    gpuBoost.ac = 10;
    gpuBoost.battery = 0;
  };

  # Çıplak Fn tuşu F20 (HID usage 0x7006f) gönderiyor ve xkb bunu
  # XF86AudioMicMute'a eşlediği için her Fn basışı mikrofonu aç/kapa
  # yapıyordu (basılı tutunca tekrar bile ediyor). Kernel seviyesinde sustur.
  # Dahili klavye: USB-HID 0414:8104 (GIGABYTE).
  services.udev.extraHwdb = ''
    evdev:input:b0003v0414p8104*
     KEYBOARD_KEY_7006f=reserved
  '';

  # ---------------------------------------------------------------------------
  # ÖLÇÜM DEFTERİ — 16 Ağu 2026 fan modu karşılaştırması
  # ---------------------------------------------------------------------------
  # ⚠️ BU TABLO ARTIK ŞÜPHELİ (7 Eyl 2026). `aorus_laptop`'ın numaralandırmasıyla
  # alındı, ve o numaralandırmanın PECM+0x2C desenlerine eşlenmediği yukarıda
  # ölçüldü — hangi deseni ölçtüğü ADJF geçmişine bağlı ve belirsiz. Dördü de
  # belirgin biçimde farklı davrandığına göre dört AYRI desendi, ama hangisinin
  # hangisi olduğu bilinmiyor. Yeni sürücünün isimleriyle YENİDEN ÖLÇÜLMELİ:
  #   quiet · balanced · responsive · gaming · turbo
  #
  # Ölçümün kısası (4 thread Zen5, 60 sn, aynı yük):
  #   mod 4  98.1°C  53.9W  4849MHz  fan 4388/4556   boşta fan DURUR
  #   mod 1  95.0°C  45.3W  4742MHz  fan 2354/2715   boşta fan DURUR
  #   mod 2  99.4°C  53.3W  4840MHz  fan 4893/5186   boşta fan DÖNER (2156)
  #   mod 5  97.0°C  55.1W  4860MHz  fan 6362/6455   boşta fan DÖNER (6594)
  #
  # İki şey öğrenildi (bunlar desen belirsizliğinden ETKİLENMİYOR):
  # 1) Fan sürekli sıcaklığı DÜŞÜRMÜYOR, performansa çeviriyor. Mod 4→5'te hava
  #    %45 artıyor, sıcaklık yalnız 1.1°C düşüyor; kazanç güce (53.9→55.1W) ve
  #    saate (4849→4860MHz) gidiyor. Boost algoritması Tjmax'i HEDEFLİYOR.
  #    Yani "sürekli yükte 99°C" fanla çözülebilir bir problem değil.
  # 2) Mod 1 istisna: fan eğrisi değil, 95.0°C hedefli KAPALI ÇEVRİM denetleyici.
  #    8. sn'den itibaren Tctl tam 95.0'da çakılı; hedefi tutmak için gücü
  #    (51→45W) ve saati (4840→4742MHz) kırpıyor. Bedeli %2.1 saat, karşılığı
  #    4.4°C + fanın yarı devri.
  # NOT: wmi-ec.md'nin eski "4/5 ölü" ve "mod 2-4 etkisiz olabilir" notları YANLIŞ —
  # dördü de canlı sistemde belirgin biçimde farklı davranıyor (16 Ağu ölçümü).
  #
  # fan_mode İSTİSNASI (10 Ağu 2026, modülde KORUNUYOR): AC/uyanış tetikleyicisi
  # game-perf.service oyun ortasında turbo yazmışken araya girip geri almamalı.
  # `aero-power-profile` bunu `systemctl is-active game-perf.service` ile
  # koşullandırıyor; ACBT dalı koşulsuz kalıyor. `is-active` burada doğru sorgu:
  # game-perf Type=oneshot + RemainAfterExit=true, yani "oyun oturumu sürüyor mu"
  # sorusunun tam karşılığı — zapret defterindeki "is-active ile sağlık ölçme"
  # tuzağıyla AYNI ŞEY DEĞİL (orası Restart=always bir daemon'du).
}
