# Zapret — DPI bypass (anti-manyeski). nfqws NFQueue daemon'u + nftables
# yönlendirmesi. Trafikten 80/443 TCP ve 443 UDP'yi (QUIC) NFQ 200'e yönlendirir,
# nfqws de fake/split desync ile DPI durum makinesini bozar.
#
# NEDEN nfqws (tpws DEĞİL): tpws bir transparent proxy; uygulamaların onu nasıl
# geçeceği protokole özgü ve QUIC'i uçtan uca proxy edemez. nfqws paket
# işlemede çalışır — kaynaktan hedefe giden trafiği yerinde bozar; QUIC dâhil her
# L7'ye uygulanabilir. Tek daemon yeter.
#
# Mullvad ile ÇAKIŞMA: vpn.nix'te mullvad `enable = false` yapıldı (01 Ağu 2026).
# NEDEN: Mullvad tun0 arayüzünü default route'a yazar; zapret'in nfqueue kuralı
# OUTPUT hook'unda paketleri NFQ'ya çeker. İkisi aynı output paketlerini manipüle
# etmeye kalkınca tun0'a giden paketler zapret'e düşer → karşılıklı bozulma. Tek
# cihazda ikisini bir arada tutmanın temiz yolu yok; yalın zapret tercih edildi.
#
# İDLE BÜTÇESİ: nfqws paket geldikçe çalışır. Paket akışı olmadan CPU kullanımı
# sıfır (epoll wait). 4.28W idle tabanına dokunmaz. Tek maliyet: NFQueue kuralı
# her output paketinde nftables'dan geçer — ama kural match etmeyen paketler
# (成立的 flow, 80/443 dışı portlar) accept ile kernel'den devam eder, ek CPU yok.
#
# STRATEJİ: `--dpi-desync=fake,split2 --dpi-desync-autottl` — TR'de Discord/Telegram/
# YouTube/Google için ölçülmüş en sağlam genel strateji. `--dpi-desync-fake-tls-mod=
# rndsni` fake TLS SNI'yi rassal yapar (DPI'nin SNI indeksleme girişimini bozar).
# `--dpi-desync-repeats=6` fake paketi 6 defa gönderir (kaybedilirse kaybedilir
# cumhuriyet). `--dpi-desync-fooling=badseq` fake paketlerin seq'sini bozar → alıcı
# discard eder, DPI ise "established" sanayı durumu bozar.
# UDP 443 (QUIC): `udplen` desync sırasında paket uzunluğunu değiştirir (DPI
# substring bekleyişini bozar). Ayrı `--new` strategi bloğu, `--filter-l7=quic`.
#
# Konfigürasyon değişimi: blok içeriği `--hostlist` ile sınırlamak (yalnız
# engellenmiş alan adlarına uygula) yerine evrensel bırak — trafiğin %99'u
# engellenmemiş olsa da fake paket maliyeti ihmal edilebilir ve "her alan adını
# elle bakım" derdi yok.
#
# blockcheck ile bireysel alan adı kırılımı doğrulanır:
#   sudo blockcheck example.com
{ pkgs, ... }:

let
  inherit (pkgs) zapret;
  # NFQueue numarası. 200 — modüllerin varsayılan boş aralığı; çakışma yok.
  NFQ_NUM = 200;
  # PID/sock dosyaları /run altında — reboot'ta temizlenir.
  PIDFILE = "/run/zapret/nfqws.pid";

  # nfqws daemon argümanları. `--new` ile ayrı strategi blokları.
  # filter-l3 / filter-tcp / filter-udp — her strategi için trafik filtre.
  #
  # STRATEJİ: blockcheck pornhub.com üstünde 01 Ağu 2026'da ölçüldü. Mevcut
  # `multidisorder` YouTube/Google üstünde çalışiyor ama KARA LİSTEDEKİ
  # SNI'ler üstünde (pornhub, xvideos) başarısız: Türk operatör DPI'sıSelective
  # — yalnız yasaklı domain listesi için SNI yakalıyor, diğerlerinde gevşek.
  # Bu nedenledir ki "Google çalışıyor" pornhub'ta başarı demek değildir.
  #
  # blockcheck'in pornhub için WORKING dediği stratejiler: `fake --ttl=3`,
  # `fakedsplit --ttl=3 --split-pos=1`, `hostfakesplit --ttl=3`. TLS handhake'in
  # ilk başında FAKE bir ClientHello gönder, kısa TTL (3) ile DPI adımda ölür,
  # (DPI fake'i işlenmiş sanır , orijinal ClientHello'ya RST yol açmaz).
  #
  # HTTP (80) ve HTTPS (443) için AYNI profil kullanilir — blockcheck ikisinde
  # de WORKING gordu. `--dpi-desync-ttl=3` sabit (3 hop sonrada fake paket ölür:
  # kullanının evi↔DSLAM↔operatör DPI'sı tipik 3 hop). `--dpi-desync-fooling=ts`
  # TCP Timestamp options'ı bozar (DPI хуже State mændia).
  nfqwsArgs = [
    "--qnum=${toString NFQ_NUM}"
    # --- HTTP+HTTPS strategi (port 80/443) ---
    # blockcheck WORKING: `nfqws --dpi-desync=fake --dpi-desync-ttl=3`
    # ve `nfqws --dpi-desync=fake --dpi-desync-fooling=ts`
    # `--dpi-desync-fooling=ts` kullanıldı (sabıt TTL ile birleşince en sağlam).
    "--new"
    "--filter-l3=ipv4"
    "--filter-tcp=80,443"
    "--dpi-desync=fake"
    "--dpi-desync-ttl=3"
    "--dpi-desync-fooling=ts"
    # --- UDP strategi (443/QUIC) ---
    # `fake,udplen`: once fake QUIC Initial, sonra paket uzunlugunu degistir.
    # fake-quic-mod YOK (nfqws v72.13); default fake yeterli.
    "--new"
    "--filter-l3=ipv4"
    "--filter-udp=443"
    "--filter-l7=quic"
    "--dpi-desync=fake,udplen"
    "--dpi-desync-autottl"
    "--dpi-desync-repeats=6"
  ];

  # nfqws args'ı tek shell string'ine celeleştir (her arg tek tırnak içinde).
  nfqwsCmd = "${zapret}/bin/nfqws " + (pkgs.lib.concatMapStringsSep " " (a: "'${a}'") nfqwsArgs);
in
{
  # nfnetlink_queue kernelde mevcut; auto-load etmez, elle yükle. nf_conntrack
  # zaten varsayılan yüklü ama emin olalım (UDP conntrack için).
  boot.kernelModules = [ "nfnetlink_queue" "nf_conntrack" ];

  # NixOS nftables — localsend (openFirewall) ile entegre çalışır. `tables`
  # seçeneği firewall kurallarını bozmadan yeni tablo ekler; networking.firewall
  # kendi `inet filter` tablosunu kurar, bizim `inet zapret` ayrı.
  networking.nftables.enable = true;
  networking.nftables.tables.zapret = {
    family = "inet";
    # content = tüm tablo (chain tanımları dahil). OUTPUT hook, mangle priority —
    # routing'den ÖNCE, paket henüz hazezlenmemiş. nfqws fake paketleri kendi raw
    # socket'inden oluşturur; onlar bu hook'tan GEÇMEZ (socket → pmtu bypass) →
    # sonsuz döngü yok.
    content = ''
      chain zapret_out {
        type filter hook output priority mangle; policy accept;

        # established/related flow ilk paket dışında NFQ'ya gönderme — DPI düzeltme
        # yalnız bağlantının ilk paketinde anlamlı. established paketleri kernel
        # kendisi forward etsin, nfqws'i yorma.
        ct state { established, related } accept comment "zapret: established flow bypass"
        ct state invalid accept comment "zapret: invalid state bypass"

        # TCP 80/443 — ilk paket (new) kuyrukla. flags bypass: nfqws düşerse paket
        # kernel normal yolundan devam etsin (servis boot'ta henüz hazırken).
        # nft queue sözdizimi: `queue [flags F] to N` — flags önce, sonra `to N`.
        ip protocol tcp tcp dport { 80, 443 } ct state new queue flags bypass to ${toString NFQ_NUM} comment "zapret: TCP 80/443 -> nfqws"

        # UDP 443 (QUIC) — ct state new ilk paket (kernel UDP conntrack açıyorsa).
        # nfqws kendisi de conntrack sürdürdüğü için tekrar tekrar paket düşmez.
        ip protocol udp udp dport 443 ct state new queue flags bypass to ${toString NFQ_NUM} comment "zapret: UDP 443 (QUIC) -> nfqws"
      }
    '';
  };

  # nfqws daemon — arka planda, boot'ta başlar.
  # Type=simple: --daemon fork'lamıyor, doğrudan foreground'da systemd kontrol ediyor.
  # Bu stderr'ın journal'a düşmesini sağlar; hata anında görürüz. --daemon kaldırıldı.
  # Sandbox: nfqws nfqueue socket için NETLINK + raw socket açar; PrivateTmp ve
  # RestrictNamespaces kuralı nfnetlink'i kırabiliyor. Sandbox'ı minimum tutalım —
  # paket geldikçe çalışan daemon, gerçek bir sandbox attack surface'i değil.
  systemd.services.zapret = {
    description = "Zapret nfqws — DPI bypass (fake/split desync)";
    wantedBy = [ "multi-user.target" ];
    # nftables kuralları yüklendikten SONRA başlat; nfqueue kuralı olmazsa nfqws
    # paket almaz (kabul edilebilir ama Toast mesajı olur).
    after  = [ "nftables.service" "network.target" ];
    wants  = [ "nftables.service" ];
    path = [ zapret pkgs.nftables ];
    serviceConfig = {
      Type = "simple";
      ExecStart = nfqwsCmd;
      # durdurma: --user=nobody drop ettiği için root SIGTERM atar.
      ExecStop = "${pkgs.coreutils}/bin/kill $MAINPID";
      Restart = "on-failure";
      RestartSec = "3";
      # güvenlik: nfqueue'ya erişmesi için CAP_NET_ADMIN + CAP_NET_RAW gerek.
      # PrivateTmp=true / RuntimeDirectory zapret'i sağlar; sandbox kalan
      # kısıtları çıkardım çünkü nfqws nfnetlink raw socket açamıyordu.
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_NICE" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_NICE" ];
      RuntimeDirectory = "zapret";
      RuntimeDirectoryMode = "0755";
    };
  };

  # blockcheck — elle çağrılır, sudo blockcheck example.com.
  environment.systemPackages = [ zapret ];
}
