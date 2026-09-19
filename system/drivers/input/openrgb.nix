# OpenRGB — çevre birimi RGB'si, ve dahili klavye için satıcı protokolü köprüsü.
#
# NEDEN VAR: dahili klavyenin renk yolu bugün `keyboard-rgb/` (HID LampArray).
# Ama LampArray bu cihazda tek bölge ve efekt seçtirmiyor; klavyenin ASIL
# yetenekleri satıcı kanalında (0xFF01) duruyor ve OpenRGB o protokolü
# ZATEN BİLİYOR — yalnız bizim PID'imizi tanımıyordu.
#
# ÖLÇÜM (19 Eyl 2026) — protokolün bizde de geçerli olduğunun kanıtı:
#   OpenRGB detector'ü:  VID 0x0414, arayüz 3, usage page 0xFF01, usage 0x01
#   bizim klavye:        input3 = 0xFF01, usage 0x01  → BİREBİR aynı yer
#   OpenRGB rapor boyu:  8 bayt feature, Report ID YOK
#   bizim descriptor:    95 08 b1 02 (8 baytlık feature), unnumbered → AYNI
#   OpenRGB parlaklık:   0x00..0x32
#   Fn+Space ölçümümüz:  0x00, 0x18, 0x20, 0x32 → aynı ölçek, 0x32 tam tavan
# Canlı yazma denendi (`08 01 RR GG BB Br 00 <checksum>` → /dev/hidraw8):
# HIDIOCSFEATURE kabul edildi.
#
# Desteklenen PID'ler upstream'de 7A3F/7A42/7A43/7A44 (Aorus 17X, 15BKF).
# Bizimki 0x8104 → postPatch ile detector'e ekleniyor. Yama TEK SATIR: aynı
# çağrıyı bizim PID'imizle tekrar kaydediyor, protokol kodu değişmiyor.
#
# BOŞTA GÜÇ (CLAUDE.md kural 6): `services.hardware.openrgb` bir SDK server
# servisi açar ve o BOŞTA DÖNER — 4.28 W bütçesini ihlal eder. Bu yüzden servis
# AÇILMIYOR; OpenRGB yalnız paket olarak kurulu, kullanıcı çalıştırınca çalışıyor.
# udev kuralları paketten geliyor (services.udev.packages), cihaz erişimi için
# servise gerek yok.
{ pkgs, ... }:

let
  # AERO X16 EG61H klavyesi (0414:8104) upstream listede yok. Aynı satıcı
  # protokolünü konuştuğu ölçüldü (yukarı bak), bu yüzden var olan Aorus
  # detector'üne bir kayıt daha ekliyoruz.
  #
  # ⚠️ CLAUDE.md kural 3: bu `''…''` bloğunun İÇİ script metnidir — buradaki
  # her düzeltme OpenRGB'yi YENİDEN DERLETİR (C++ projesi, dakikalar sürer).
  openrgb-aero = pkgs.openrgb.overrideAttrs (eski: {
    postPatch = (eski.postPatch or "") + ''
      cat >> Controllers/GigabyteAorusLaptopController/GigabyteAorusLaptopControllerDetect.cpp <<'YAMA'

      /* AERO X16 EG61H (0414:8104) — NixOS yaması, bkz. system/drivers/input/openrgb.nix.
         Aorus laptop protokolüyle birebir aynı: arayüz 3, usage page 0xFF01,
         usage 0x01, 8 baytlık unnumbered feature report. Ölçüm 19 Eyl 2026. */
      REGISTER_HID_DETECTOR_IPU("Gigabyte AERO X16 Keyboard", DetectGigabyteAorusLaptopKeyboardControllers, 0x0414, 0x8104, 3, 0xFF01, 0x01);
      YAMA
    '';
  });
in
{
  environment.systemPackages = [ openrgb-aero ];

  # Cihaz erişimi için udev kuralları (paketin kendi 60-openrgb.rules'u).
  # Dahili klavyemiz için ZATEN bir uaccess kuralımız var (keyboard-rgb/system.nix,
  # 70-kbd-rgb.rules) — bu paket onu diğer çevre birimleri için tamamlıyor:
  # fare (Glorious Model I), harici klavye vb.
  services.udev.packages = [ openrgb-aero ];

  # i2c-dev: OpenRGB anakart/RAM RGB'si için ister. Dizüstüde karşılığı yok ama
  # modül yüklü değilse OpenRGB her açılışta uyarı basar. Boşta maliyeti yok
  # (yüklü modül, dönen süreç değil).
  hardware.i2c.enable = true;
}
