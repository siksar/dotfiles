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

    # AC'de `responsive`, pilde `balanced` — AYRIM KASITLI (12 Eyl 2026).
    #
    # İki mod AYNI duty merdivenini kullanıyor (18·20·21·23·26·29·33…38·43);
    # tek fark eşiklerin ~14 °C erkene kayması. Firmware tablosundan, fan 0
    # (aero-sysfs/src/curves.rs, kaynak 0x05B92 vs 0x05CBE):
    #     responsive  40→18%  46→20%  51→21%  56→23%  60→26%  64→29%  67→33%
    #     balanced    54→18%  60→20%  66→21%  69→23%  72→26%  75→29%  78→33%
    # Yani responsive daha GÜRÜLTÜLÜ değil, daha ERKEN: aynı havayı daha düşük
    # sıcaklıkta veriyor, tavan ikisinde de %43. Sürekli yükte ikisi de tavana
    # dayandığı için fark yok; kazanç kısa patlamalarda (derleme, oyun açılışı)
    # sıcaklığın 90 °C'ye hiç tırmanmaması.
    #
    # PİLDE NEDEN DEĞİL: boşta ölçüm (12 Eyl, AC, masaüstü açık) CPU 54-57 °C
    # ve fanlar 0 RPM. responsive'in 51 °C eşiği bu tabanın ALTINDA — yani
    # pilde fan boşta dönmeye başlar ve 4.28 W boşta bütçesi (CLAUDE.md kural 6)
    # ölçülmeden riske girer. Pil tarafı ancak `scripts/idle-baseline.sh` ile
    # A/B ölçüldükten sonra değiştirilmeli.
    fanMode.ac = "responsive";
    fanMode.battery = "balanced";

    # Şarj limiti %80 (12 Eyl 2026, kullanıcı isteği — önceki değer 60).
    # 80 tahmin değil: `aero-set-charge@80` 8 Eyl'de köprü testinde yazılıp geri
    # okunmuştu. Sürücü her yazımı GERİ OKUYUP doğruluyor, uyuşmazlıkta -EIO
    # döner; ayrıca kendi uyanış kancası var (7 Eyl: "uyanis: ... korunmus").
    # DİKKAT: EC limiti AŞAĞI doğru uygulamıyor — pil şu an bunun üstündeyse
    # (ör. %99) boşalana kadar hiçbir şey olmaz, sonra 80'de durur.
    chargeLimit = 80;

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
