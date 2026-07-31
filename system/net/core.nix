# Ağ yığını: NetworkManager, systemd-resolved önbelleği, BBR+fq+TFO,
# TR regdomain, kablo↔WiFi hakemi (kablo takılınca WiFi kapanır).
{ pkgs, ... }:

let
  # --- Kablo↔WiFi hakemi (arbiter) ---
  # Ethernet kablosu takılıyken (eno1 carrier=1) WiFi radyosunu kapatır, kablo
  # çıkınca (carrier=0) geri açar. NEDEN: kullanıcı tercihi — kabloluyken tek
  # yol/daha az uyanma; masaüstünde/fişte genelde kablo var. Kesintisiz failover
  # yerine bilinçli olarak WiFi'ı susturuyoruz.
  #
  # carrier okuması: NM eno1'i IFF_UP tutar (plug olayını yakalamak için), o yüzden
  # /sys/.../carrier kablo yokken 0, varken 1 döner. Boot çok erken çalışırsa (NM
  # daha eno1'i up etmeden) okuma düşer → `|| echo 0` → güvenli varsayılan (WiFi açık);
  # NM eno1'i up edince dispatcher düzeltir.
  #
  # Kablosuz arayüz olaylarını (wlan0) YOK SAYARIZ: aksi halde "wifi off" komutu
  # wlan0 down olayını tetikleyip dispatcher'ı tekrar çağırır → gereksiz churn.
  # Yalnız kablolu carrier'a bakıp idempotent davranırız.
  ethWifiArbiter = pkgs.writeShellScript "eth-wifi-arbiter" ''
    IFACE="''${1:-}"
    [ -n "$IFACE" ] && [ -d "/sys/class/net/$IFACE/wireless" ] && exit 0
    [ "$IFACE" = "lo" ] && exit 0

    CARRIER=$(${pkgs.coreutils}/bin/cat /sys/class/net/eno1/carrier 2>/dev/null || echo 0)
    if [ "$CARRIER" = "1" ]; then
      ${pkgs.networkmanager}/bin/nmcli radio wifi off 2>/dev/null || true
    else
      ${pkgs.networkmanager}/bin/nmcli radio wifi on 2>/dev/null || true
    fi
  '';
in
{
  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";

    # DNS'i systemd-resolved'e devret → yerel önbellek (tekrar sorgular anında,
    # gezinme hızlanır). NM, DHCP ve Mullvad'ın per-link DNS sunucularını resolved'e
    # iter; şifrelemeyi VPN üstlenir (aşağıda DoT kapalı).
    dns = "systemd-resolved";

    # Kablo↔WiFi hakemi olay-temelli tetikleyici: eno1 up/down (kablo tak/çıkar)
    # olduğunda arbiter'ı çağırır. (Boot ilk senkronu ayrıca aşağıdaki oneshot'ta.)
    dispatcherScripts = [
      { source = ethWifiArbiter; type = "basic"; }
    ];
  };
  networking.modemmanager.enable = false;

  # --- WiFi regülasyon alanı (regdomain) = TR ---
  # Varsayılan "00" (global) en kısıtlayıcı profildir: TX gücünü ve bazı 5GHz
  # kanallarını gereksiz kısar. TR'ye sabitlemek yasal kanal/güç tavanını açar →
  # menzil/hız düzelir. wireless-regdb sistemde mevcut olduğundan kod uygulanır.
  # Doğrulama: `iw reg get` → "country TR".
  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=TR
  '';

  # --- systemd-resolved: yerel DNS önbelleği (Mullvad uyumlu) ---
  # dnssec=false: captive portal / bazı alan adları DNSSEC katılığından kırılmasın.
  # dnsovertls=false: kullanıcı tercihi cache-only; şifreli DNS'i VPN (Mullvad) verir.
  # /etc/resolv.conf → 127.0.0.53 stub olur; Mullvad bağlanınca tünel arayüzünde
  # kendi DNS'ini per-link olarak resolved'e yazar, çözümleme sürer.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "false";
      DNSOverTLS = "false";
    };
  };

  # --- Ağ yığını: BBR tıkanıklık kontrolü + fq qdisc + TCP Fast Open ---
  # BBR, kayıplı/gecikmeli kablosuz hatta cubic'ten belirgin daha iyi throughput
  # verir; fq qdisc BBR'nin paket "pacing"i için ideal eş; TFO el sıkışmayı bir
  # RTT kısaltır (bağlantı kurulumu hızlanır). Güç etkisi ihmal edilebilir.
  # tcp_bbr/sch_fq modülleri kernelde mevcut. (sysctl merge-tipli → power.nix ile
  # çakışmaz.)
  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.core.default_qdisc"          = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen"           = 3;
  };

  # Kablo↔WiFi hakemi boot ilk senkronu: boot'ta bir kez koşup mevcut kablo
  # durumuna göre WiFi'ı ayarlar. NEDEN gerekli: "kablolu iken kapat" sırasında
  # WiFi kapalı kalır ve NM bunu (/var/lib/NetworkManager) kalıcılaştırır; sonra
  # kablosuz boot edilirse eno1 hiç "up" olayı üretmez → dispatcher tetiklenmez →
  # WiFi kapalı takılırdı. Bu oneshot o uç durumu (kablo yoksa WiFi'ı geri açarak)
  # çözer. (power-display'deki "boot'ta VE olayda koş" deseninin ağ karşılığı.)
  systemd.services.eth-wifi-arbiter = {
    description = "Kablo takılıysa WiFi'ı kapat (boot ilk senkronu)";
    wantedBy = [ "multi-user.target" ];
    after    = [ "NetworkManager.service" ];
    wants    = [ "NetworkManager.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = ethWifiArbiter;
    };
  };

  # NetworkManager-wait-online kapalı (2026-07-18). Bu servis boot'ta ~49s bekliyordu
  # (eth+wifi ikisi bağlıyken biri geç DHCP/carrier alıyor) ve network-online.target →
  # graphical.target zincirini kilitliyordu. uwsm'in start-hyprland'ı derleyiciyi
  # sistem graphical.target'ı aktifleşene kadar başlatmadığından, giriş sonrası 10-20s
  # boş ekran (yanıp sönen imleç) tam olarak bu beklemeydi. Dizüstünde grafik oturumunu
  # "ağ tam hazır" olmasına kilitlemenin bir gereği yok; tek ardıl mullvad-daemon zaten
  # ağ gelip gitmesini kendi yönetiyor. Kapatınca graphical.target ~3s'de gelir → giriş
  # anlık, boot ~49s kısa.
  systemd.services.NetworkManager-wait-online.enable = false;
}
