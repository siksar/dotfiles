# Sansür aşma: zapret/nfqws (DPI'yi bozar) + dnscrypt-proxy DoH (DNS hijack). Mullvad ile çakışır (vpn.nix).
# Strateji tek kaynak: nfqwsArgs.
{ pkgs, ... }:

let
  inherit (pkgs) zapret;
  NFQ_NUM = 200;

  # Deneme: systemctl stop zapret; sudo nfqws --qnum=200 ... elle; ya da sudo blockcheck <alan>.
  # TR DPI'ı SEÇİCİ: yalnız kara listedeki bir alan adıyla doğrula.
  nfqwsArgs = [
    "--qnum=${toString NFQ_NUM}"
    # BURAYA `--new` KOYMA: ilk profil otomatik; fazla --new boş profil açar, tüm trafik oraya düşer.
    # Doğrulama: journalctl -u zapret | grep "user defined" → 2 profil.
    "--filter-l3=ipv4"
    "--filter-tcp=80,443"
    "--dpi-desync=fake"
    "--dpi-desync-ttl=3"
    "--dpi-desync-fooling=ts"
    "--new"
    "--filter-l3=ipv4"
    "--filter-udp=443"
    "--filter-l7=quic"
    "--dpi-desync=fake,udplen"
    "--dpi-desync-autottl"
    "--dpi-desync-repeats=6"
  ];

  nfqwsCmd = "${zapret}/bin/nfqws " + (pkgs.lib.concatMapStringsSep " " (a: "'${a}'") nfqwsArgs);
in
{
  boot.kernelModules = [ "nfnetlink_queue" "nf_conntrack" ];

  networking.nftables.enable = true;
  networking.nftables.tables.zapret = {
    family = "inet";
    content = ''
      chain zapret_out {
        type filter hook output priority mangle; policy accept;

        # `ct state new` KULLANMA: ClientHello el sıkışmadan sonra gelir → akışın ilk 6 paketini kuyrukla.
        # nfqws'in kendi sahte paketleri 0x40000000 mark taşır → geri kuyruğa alma (sonsuz döngü).
        meta mark and 0x40000000 == 0x40000000 accept comment "zapret: nfqws desync mark bypass"
        ct state invalid accept comment "zapret: invalid state bypass"

        # flags bypass: nfqws düşerse paket normal yoldan devam eder. Sözdizimi: `queue flags F to N`.
        ip protocol tcp tcp dport { 80, 443 } ct original packets 1-6 queue flags bypass to ${toString NFQ_NUM} comment "zapret: TCP 80/443 -> nfqws"

        # UDP 443 (QUIC) — aynı gerekçe: QUIC Initial ilk pakette gelse de
        # retry/coalesce halinde sonraki paketlere kayabiliyor.
        ip protocol udp udp dport 443 ct original packets 1-6 queue flags bypass to ${toString NFQ_NUM} comment "zapret: UDP 443 (QUIC) -> nfqws"
      }
    '';
  };

  systemd.services.zapret = {
    description = "Zapret nfqws — DPI bypass (fake/split desync)";
    wantedBy = [ "multi-user.target" ];
    after  = [ "nftables.service" "network.target" ];
    wants  = [ "nftables.service" ];
    path = [ zapret pkgs.nftables ];
    serviceConfig = {
      Type = "simple";
      ExecStart = nfqwsCmd;
      # `--user` ekleme: CAP_SETUID/SETGID olmadan initgroups döngüsünde çöker. Sağlığı NRestarts ile ölç.
      ExecStop = "${pkgs.coreutils}/bin/kill $MAINPID";
      Restart = "on-failure";
      RestartSec = "3";
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_NICE" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_SYS_NICE" ];
      RuntimeDirectory = "zapret";
      RuntimeDirectoryMode = "0755";
    };
  };

  # DoH: uygulama → 127.0.0.53 (resolved) → 127.0.0.2 (dnscrypt) → Cloudflare.
  # upstreamDefaults birleşmesi SIĞ: tanımlanan her üst düzey anahtar upstream tablosunu EZER.
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      # 127.0.0.54 KULLANILAMAZ: resolved'in ikinci dinleyicisi orada.
      listen_addresses = [ "127.0.0.2:53" ];

      # Stamp elle üretildi (dnscrypt.info/stamps); elle düzenlenmez, yeniden üret.
      server_names = [
        "cloudflare-1"
        "cloudflare-2"
      ];
      static."cloudflare-1".stamp =
        "sdns://AgcAAAAAAAAABzEuMS4xLjEAEmNsb3VkZmxhcmUtZG5zLmNvbQovZG5zLXF1ZXJ5";
      static."cloudflare-2".stamp =
        "sdns://AgcAAAAAAAAABzEuMC4wLjEAEmNsb3VkZmxhcmUtZG5zLmNvbQovZG5zLXF1ZXJ5";

      # Resolver listesi indirmesi kapalı (GitHub'dan iner, TR'de engellenebilir, restart döngüsü).
      sources = { };

      bootstrap_resolvers = [ "1.1.1.1:53" "8.8.8.8:53" ];

      require_dnssec = false;
      require_nolog = false;
      require_nofilter = false;

      cache = true;
      cache_size = 4096;
      cache_min_ttl = 600;
      cache_max_ttl = 86400;

      block_ipv6 = true;

      log_level = 0;
    };
  };

  networking.nameservers = [ "127.0.0.2" ];

  # `~.` OLMAZSA per-link DHCP DNS'i kazanır, hijack sürer. Captive portal için geçici kaldır.
  services.resolved.settings.Resolve.Domains = [ "~." ];

  environment.systemPackages = [ zapret ];
}
