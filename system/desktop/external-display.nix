# Harici ekran (HDMI) — dGPU DRM guard'ını gevşeten bayrak. 20 Eyl 2026.
#
# SORUN, 20 Eyl 2026'da CANLI MAKİNEDE ÖLÇÜLDÜ: HDMI'a takılan monitöre hiç
# görüntü gitmiyordu. Sebep compositor ayarı değil, KABLONUN NEREYE GİTTİĞİ:
#
#   /sys/class/drm/card0-HDMI-A-1  →  0000:64:00.0  →  NVIDIA RTX 5060 (dGPU)
#   /sys/class/drm/card1-eDP-1     →  0000:65:00.0  →  AMD Radeon 860M (iGPU)
#
# Bu makinede HDMI portu MUXSUZ ve doğrudan dGPU'ya bağlı — iGPU'nun o konektöre
# erişimi YOK. Kernel monitörü sorunsuz görüyordu (status=connected, EDID okunuyor,
# 1920x1080 modları listeleniyor); görüntüyü basacak olan compositor o kartı hiç
# açmıyordu:
#
#   ls -l /proc/$(pgrep -x cosmic-comp)/fd | grep dri   →  YALNIZ card1 (×4)
#
# Yani 4.28 W idle bütçesini koruyan dGPU guard'ı (cosmic.nix'te
# COSMIC_DRM_ALLOW_DEVICES, gnome.nix'te `mutter-device-ignore` udev etiketi)
# yan etki olarak HDMI çıkışını da kapatıyor. Guard bir hata değil, bu bedeli
# BİLEREK ödüyordu — ama o not yazıldığında harici ekran senaryosu yoktu.
#
# BU BAYRAK NE YAPAR: iki guard'ı da gevşetir, compositor NVIDIA'nın DRM node'unu
# da açar, HDMI konektörü sürülebilir hale gelir. dGPU-only (mux.nix) DEĞİLDİR:
# panel hâlâ iGPU'da, PRIME offload ve RTD3 açık kalır, render iGPU'da yapılır.
# Tek değişen, compositor'ın dGPU'yu "çıkış kartı" olarak da görmesi.
#
# ───────────────────────────────────────────────────────────────────────────
# BEDELİ — güç, ve neden yine de açık geliyor
# ───────────────────────────────────────────────────────────────────────────
# Kök CLAUDE.md kural 6: "4.28 W boşta bütçesi geri gitmez." Bu bayrak o kuralla
# GERİLİM İÇİNDE ve bu bilinçli bir takas:
#
#   * Harici ekran TAKILIYKEN dGPU zaten uyanık kalmak ZORUNDA — bunun etrafından
#     dolaşmanın yolu yok, kabloyu o kart sürüyor. Bu bedel kaçınılmaz.
#   * Harici ekran TAKILI DEĞİLKEN sorusu ölçülmelidir. 20 Eyl 2026'da yapılan
#     ön ölçüm (dgpu-fd-test): /dev/dri/card0'ı 20 s boyunca açık tutmak kartı
#     D3cold'dan ÇIKARMADI (power_state D3cold, runtime_status suspended sabit).
#     Ama bu test DRM master ALMIYOR ve konektör TARAMIYOR — compositor'ın
#     yaptığı şeyin tamamı değil. GUARD NOTLARININ "açık fd ~4.3W'ı ~7W'a çıkarır"
#     İDDİASI BU MAKİNEDE DOĞRUDAN ÖLÇÜLMEDİ, Plasma dönemi notundan devralındı.
#
# BU YÜZDEN SWITCH SONRASI ÖLÇÜM ZORUNLU (harici ekran TAKILI DEĞİLKEN):
#   cat /sys/bus/pci/devices/0000:64:00.0/power_state       → D3cold bekleniyor
#   ls -l /proc/$(pgrep -x cosmic-comp)/fd | grep dri       → card0 + card1
#   Documentation/aerox16/power.md yöntemi (120 s sakinleşme + 6×10 s örnek)
# D3cold korunuyorsa bedel yalnız harici ekran takılıyken ödenir ve bayrak
# kalıcı açık kalabilir. D3cold BOZULUYORSA bayrağı `false` yap — harici ekranı
# yalnız gerektiğinde aç (env PAM'den geldiği için OTURUM YENİDEN BAŞLATMA ister,
# rebuild yetmez).
#
# ÖLÇÜM SONUCU BURAYA YAZILACAK — boş kaldıysa henüz ölçülmemiştir.
#
# ───────────────────────────────────────────────────────────────────────────
# mux.nix İLE KARIŞTIRMA
# ───────────────────────────────────────────────────────────────────────────
# mux.nix (desktop.dgpuOnly) BIOS'ta MUX'u "Discrete only" yapmış olmayı varsayar,
# paneli dGPU sürer, PRIME ve RTD3 KAPANIR, 4.28 W bütçesi tamamen geçersizdir.
# Bu dosya onun küçük kardeşi değil, farklı bir şey: hibrit mod korunur.
# İkisi aynı anda açılırsa dgpuOnly kazanır (o `lib.mkForce` yazıyor, buradaki
# değer cosmic.nix'te DÜZ atama olarak kalıyor) — çakışma değil, ama anlamsız
# kombinasyon olduğu için aşağıda uyarı var.
{ config, lib, ... }:

let
  cfg = config.desktop.externalDisplay;
in
{
  options.desktop.externalDisplay.enable = lib.mkEnableOption ''
    harici ekran (HDMI) — compositor dGPU'nun DRM node'unu da acar.
    HDMI portu bu makinede MUXSUZ ve dogrudan NVIDIA dGPU'ya bagli;
    guard acikken o konektor hic surulemez. Hibrit mod korunur (mux.nix DEGIL)
  '';

  config = lib.mkIf cfg.enable {
    # Değerlerin kendisi guard'ların yaşadığı dosyalarda koşullu:
    #   system/desktop/cosmic.nix → COSMIC_DRM_ALLOW_DEVICES'e dGPU eklenir
    #   system/desktop/gnome.nix  → `mutter-device-ignore` udev kuralı yazılmaz
    # Buraya kopyalanmadılar: bir gerçeğin ikinci evi olursa orası eskir
    # (kök CLAUDE.md). Bu dosya yalnız bayrağı ve gerekçeyi taşır.

    warnings = lib.optional config.desktop.dgpuOnly.enable ''
      desktop.externalDisplay.enable = true iken desktop.dgpuOnly.enable = true
      ANLAMSIZ: dgpuOnly zaten compositor'ı SADECE dGPU'ya bağlar ve bu bayrağın
      eklediği izni mkForce ile ezer. Birini kapat.
    '';
  };
}
