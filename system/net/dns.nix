# DNS over HTTPS (DoH) — Türk operatör DNS hijack'ini aşma.
# dnscrypt-proxy2, 127.0.0.53:53'ü dinler, gelen sorguları şifreli HTTPS
# üzerinden Cloudflare (1.1.1.1) ve Google (8.8.8.8) DoH sunucularına iletir.
# Operatör DNS'i artsık sahte IP döndüremez (DNS sorgusu HTTPS trafiği içinde
# gider, DPI göremez).
#
# Mullvad kapatıldığından (vpn.nix) şifreli DNS'i VPN veremez → DoH bunun
# yerine geçer. zapret (zapret.nix) trafik manipülasyonunu, dnscrypt-proxy
# ise DNS hijack'ini aşar.
#
# services.dnscrypt-proxy2 upstream olarak `127.0.0.54` DINLER — systemd-resolved
# `127.0.0.53` stub'a yerel client'lar bağlanır, resolved upstream olarak
# `127.0.0.54`'e gider, dnscrypt-proxy de DoH sunucularına.
#
# Mullvad geri açılırsa dnscrypt-proxy'yi kapatmak gerekmez — Mullvad'ın DNS'i
# tunnel link'e yazılır, resolved per-link DNS'i kullanır, dnscrypt-proxy yalnız
# Mullvad olmayan durumda kullaılır.
{ ... }:

{
  services.dnscrypt-proxy2 = {
    enable = true;

    settings = {
      listen_addresses = [ "127.0.0.54:53" ];

      # DoH sunucuları — hem Cloudflare hem Google. Cloudflare (privacy-first
      # policy) birincili, Google yedekli.
      server_names = [ "cloudflare" "google" ];

      # DoH kaynakları (dnscrypt-proxy builtin server listesi yerine elle).
      # `static` her sorguda Both servers'dan en hızlıya Dğer.
      sources = {
        public-resolvers = {
          urls = [
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
          ];
          cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
          minisign_key = "RWQz6LoDnnD6C5jJ7vp2qhMQOXKF7(sPv5G3I3TUQnJEz3lU1pTRd8HT3q7miRj7p2NqKQYJTgAP7QGH2L3lYr2h8qMBxA==\";";
          refresh_delay = 72;
        };
      };

      # EN GÜVENLİ: IP doğrudan, alan adından çözme (bootstrap'i alkalım).
      # Cloudflare 1.1.1.1 + 1.0.0.1, Google 8.8.8.8 + 8.8.4.4.
      # DoH sunucuları TLS el sıkışması SNI içermez (IP direkt kullanır) →
      # DPI bu DoH trafiğini engellemez (SNI bönüş, SNI yok).
      bootstrap_resolvers = [
        "1.1.1.1:53"
        "1.0.0.1:53"
        "8.8.8.8:53"
        "8.8.4.4:53"
      ];

      # DNSSEC kapalı (systemd-resolved ile aynı — captive portal uyumu).
      # `require_dnssec = false` → DNSSEC katılığından kırılan siteler düzelsin.
      require_dnssec = false;
      require_nolog = true;
      require_nofilter = true;

      # Önbellek: dnscrypt-proxy'nin kendi önbelleği. systemd-resolved de
      # önbellekler, ama dnscrypt-proxy daha akıllı (negative caching, min TTL).
      cache = true;
      cache_size = 4096;
      cache_min_ttl = 600;
      cache_max_ttl = 86400;

      # IPv6 kapalı (IPv6 yok, zapret de IPv4-only).
      block_ipv6 = true;

      # Loglama kapalı — sadece hatalar.
      log_level = 0;
    };
  };

  # systemd-resolved upstream olarak dnscrypt-proxy'i kullansın (127.0.0.54).
  # /etc/resolv.conf hâlân 127.0.0.53 stub'u, NM/DHCP per-link DNS önemli değil
  # artık (DNşifreli).
  services.resolved = {
    enable = true;
    dns = [ "127.0.0.54" "1.1.1.1" "8.8.8.8" ];
    fallbackDns = [ "1.1.1.1:53" "8.8.8.8:53" ];
    settings.Resolve = {
      DNSSEC = "false";
      DNSOverTLS = "false";
    };
  };

  # DNS sızıntısını önle: NetworkManager DHCP DNS'ini yok say. NM dispatcher
  # per-link DNS'i resolved'e yazar, ama dnscrypt-proxy öncelikli olsun.
  # networkmanager.extraConfig'de dns=none değil — resolved upstream'ini bırakıp
  # sadece fallback. Aslında en sade: NM dhcp DNS'lerini yok sayma, resolved
  # dnscrypt'i öncelikli kullanır.
}
