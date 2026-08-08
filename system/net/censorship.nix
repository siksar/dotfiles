# Sansür aşma katmanı — İKİ kol, tek dosya:
#   1) zapret/nfqws  : DPI'nin TCP/UDP durum makinesini bozar (trafik)
#   2) dnscrypt-proxy: DNS'i HTTPS'e sokar (isim çözümleme)  ← dosyanın sonunda
# İkisi AYNI sorunun iki yarısı: nfqws doğru adrese giden trafiği kurtarır,
# DoH ise adresin kendisinin sahte olmamasını sağlar. Biri olmadan diğeri yarım.
#
# nfqws NFQueue daemon'u + nftables yönlendirmesi: 80/443 TCP ve 443 UDP'yi
# (QUIC) NFQ 200'e yönlendirir, nfqws de fake desync ile DPI'yı şaşırtır.
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
# (akışın 6. paketinden sonrası, 80/443 dışı portlar) accept ile kernel'den
# devam eder, ek CPU yok.
#
# STRATEJİ — aşağıdaki nfqwsArgs ile BİREBİR aynı kalmalı:
#   TCP 80/443 : --dpi-desync=fake --dpi-desync-ttl=3 --dpi-desync-fooling=ts
#   UDP 443    : --dpi-desync=fake,udplen --dpi-desync-autottl
#                --dpi-desync-repeats=6
# Bu iki yerin sapması gerçek bir hataya yol açtı: 08 Ağu 2026 denetimine kadar
# burada `fake,split2 --autottl --fooling=badseq --fake-tls-mod=rndsni` yazılıydı
# (kodda öyle bir argüman YOK) ve yanlış hali MAINTAINERS'a da kopyalanmıştı.
# Argümanları değiştirirsen bu paragrafı ve MAINTAINERS'ı aynı commit'te güncelle.
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

  # nfqws daemon argümanları. `--new` ile ayrı strateji blokları.
  # filter-l3 / filter-tcp / filter-udp — her strateji için trafik filtresi.
  #
  # ════════════════════════════════════════════════════════════════════════
  # BYPASS YÖNTEMLERİYLE OYNAMAK — buradan başla
  # ════════════════════════════════════════════════════════════════════════
  # Yöntem adlarını EZBERDEN yazma; geçerli liste sürüme bağlı ve değişiyor:
  #   nfqws --help | less        → o an kurulu sürümün desteklediği tüm
  #                                --dpi-desync yöntemleri ve fooling modları
  #
  # DOĞRU İŞ AKIŞI (rebuild etmeden dene, sonra kalıcılaştır):
  #   1) sudo systemctl stop zapret          # kuyruğu boşalt, çakışma olmasın
  #   2) sudo nfqws --qnum=200 --dpi-desync=<deneme> ...   # elle, ön planda
  #      (nftables kuralı ayakta kalır; nfqws düşerse `queue flags bypass`
  #       sayesinde trafik normal yoldan akmaya devam eder → internet kesilmez)
  #   3) çalışan kombinasyonu nfqwsArgs'a yaz, rebuild, `systemctl status zapret`
  #   4) STRATEJİ paragrafını (dosya başı) ve MAINTAINERS'ı güncelle
  #
  # Ya da doğrudan ölçtür — blockcheck WORKING/FAILED tablosu basar:
  #   sudo blockcheck example.com
  #
  # ⚠ TR DPI'sı SEÇİCİ — en pahalı tuzak bu:
  # Operatör yalnız kara listedeki alan adları için SNI yakalıyor, gerisinde
  # gevşek davranıyor. Dolayısıyla "YouTube/Google açılıyor" bir doğrulama
  # DEĞİLDİR. Strateji değiştirdiğinde MUTLAKA kara listedeki bir alan adıyla
  # ölç, yoksa hiçbir şeyi bozmadığını sanarak bozarsın.
  #
  # ÖLÇÜM (blockcheck, pornhub.com, 01 Ağu 2026) — WORKING çıkanlar:
  #   fake --ttl=3  |  fakedsplit --ttl=3 --split-pos=1  |  hostfakesplit --ttl=3
  # Seçilen: `fake`. Mantığı: TLS el sıkışmasının başında SAHTE bir ClientHello
  # gönder; kısa TTL (3) ile bu paket DPI'yı geçtikten hemen sonra ölür, sunucuya
  # hiç varmaz. DPI sahte olanı gerçek sanıp durumunu ona göre kurar, gerçek
  # ClientHello'yu artık "yeni bağlantı" gibi denetlemez → RST gelmez.
  #   --dpi-desync-ttl=3  : sabit 3 hop (ev↔DSLAM↔operatör DPI'sı tipik mesafe).
  #                         autottl yerine sabit, çünkü bu hatta ölçülen değer bu.
  #   --dpi-desync-fooling=ts : sahte paketin TCP Timestamp option'ını bozar →
  #                         gerçek sunucu paketi zaten atar, yalnız DPI yutar.
  # HTTP (80) ve HTTPS (443) AYNI profili kullanır; blockcheck ikisinde de
  # WORKING gördü, ayırmaya gerek kalmadı.
  nfqwsArgs = [
    "--qnum=${toString NFQ_NUM}"
    # ⚠ BURAYA `--new` KOYMA — ilk profil OTOMATİK yaratılır (üstakım readme,
    # "Multiple strategies": "First profile is created automatically and does
    # not require --new"). Baştaki bir `--new` fazladan bir profil daha açar ve
    # o profil BOŞ olur; boş filtre "her paketi eşler" demektir, profiller de
    # ilk eşleşende durur → bütün trafik hiçbir desync taşımayan 1. profile
    # düşer, 2. ve 3. profile sıra HİÇ gelmez. 09 Ağu 2026'da bulundu; belirti
    # sessiz: servis sağlıklı görünür, tek ipucu başlangıç kaydındaki profil
    # sayısıdır. DOĞRULAMA: `journalctl -u zapret | grep "user defined"`
    # → "2 user defined desync profile(s)" demeli. 3 diyorsa bu hata geri geldi.
    # --- HTTP+HTTPS strategi (port 80/443) — 1. profil, --new'siz ---
    # blockcheck WORKING: `nfqws --dpi-desync=fake --dpi-desync-ttl=3`
    # ve `nfqws --dpi-desync=fake --dpi-desync-fooling=ts`
    # `--dpi-desync-fooling=ts` kullanıldı (sabit TTL ile birleşince en sağlam).
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
    # routing'den ÖNCE, paket henüz hazırlanmamış. nfqws fake paketleri kendi raw
    # socket'inden gönderir ve bunlar output hook'una GERİ düşer; döngüyü kesen
    # şey aşağıdaki 0x40000000 mark kuralıdır (üstakımın yaptığı da bu).
    content = ''
      chain zapret_out {
        type filter hook output priority mangle; policy accept;

        # ⚠ BURADA `ct state new` KULLANMA — 09 Ağu 2026'da tam bunun yüzünden
        # TCP kolu hiç çalışmıyordu. `new` yalnız SYN'i eşler; oysa DPI'nın
        # baktığı şey TLS ClientHello (ya da HTTP GET), o da el sıkışmadan SONRA,
        # yani conntrack ESTABLISHED durumundayken gider. Üstelik zincirin
        # başında bir `ct state established accept` durduğu için ClientHello
        # nfqws'e hiç ulaşmıyor, desync uygulanacak paket eline geçmiyordu.
        # Belirti: DNS doğru IP'yi döndürüyor ama TLS el sıkışması RST yiyor
        # (`curl: (35) Recv failure: Connection reset by peer`).
        # Doğrusu üstakımın kendi örneği (usr/share/docs/nftables.txt):
        # bağlantının İLK 6 paketini kuyrukla — SYN, ACK ve ClientHello bu
        # aralığa girer. Sayaç zaten sınırladığı için ayrı bir established
        # kestirmesine gerek yok; idle bütçesi de korunur (uzun akışlar 6.
        # paketten sonra kernel yolundan devam eder, nfqws'e hiç uğramaz).
        #
        # nfqws'in KENDİ ürettiği sahte paketler 0x40000000 mark taşır; onları
        # geri kuyruğa almak sonsuz döngü olur (üstakımın standart koruması).
        meta mark and 0x40000000 == 0x40000000 accept comment "zapret: nfqws desync mark bypass"
        ct state invalid accept comment "zapret: invalid state bypass"

        # TCP 80/443 — akışın ilk 6 paketi. flags bypass: nfqws düşerse paket
        # kernel normal yolundan devam etsin (servis boot'ta henüz hazırken).
        # nft queue sözdizimi: `queue [flags F] to N` — flags önce, sonra `to N`.
        ip protocol tcp tcp dport { 80, 443 } ct original packets 1-6 queue flags bypass to ${toString NFQ_NUM} comment "zapret: TCP 80/443 -> nfqws"

        # UDP 443 (QUIC) — aynı gerekçe: QUIC Initial ilk pakette gelse de
        # retry/coalesce halinde sonraki paketlere kayabiliyor.
        ip protocol udp udp dport 443 ct original packets 1-6 queue flags bypass to ${toString NFQ_NUM} comment "zapret: UDP 443 (QUIC) -> nfqws"
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
      # nfqws UID=0 olarak KALIR; yetki düşürmüyoruz (`--user` YOK). Eklemeye
      # kalkarsan CAP_SETGID/CAP_SETUID da vermen gerekir: 02–09 Ağu 2026 arası
      # tam bu yüzden `initgroups: Operation not permitted` ile 44.193 kez üst
      # üste çöktü — yani zapret bir hafta boyunca fiilen ÖLÜYDÜ. Belirti sinsi:
      # `systemctl is-active` anlık yakalarsa "active" der, çünkü RestartSec=3
      # ile sürekli yeniden doğuyor. Sağlığı NRestarts ile bak, is-active ile değil:
      #   systemctl show zapret -p NRestarts -p ExecMainStartTimestamp
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

  # ══════════════════════════════════════════════════════════════════════════
  # 2. KOL — ŞİFRELİ DNS (DoH), dnscrypt-proxy üstünden
  # ══════════════════════════════════════════════════════════════════════════
  # nfqws trafiği kurtarır ama DNS'i kurtarmaz: operatör düz UDP/53 sorgusuna
  # sahte IP döndürürse (DNS hijack) bağlantı hiç doğru adrese kurulmaz, bozacak
  # bir TLS el sıkışması bile olmaz. Mullvad kapatıldığından (vpn.nix) şifreli
  # DNS'i verecek kimse kalmadı → bu blok onun yerine geçer.
  #
  # ZİNCİR:  uygulama → 127.0.0.53  (resolved stub + önbellek)
  #                   → 127.0.0.2   (dnscrypt-proxy)
  #                   → HTTPS/443 içinde NextDNS DoH (kişisel profil df5fa1)
  # Sorgu HTTPS gövdesinde gittiği için DPI ne soruyu ne cevabı görebilir.
  #
  # NEDEN NextDNS (Cloudflare/Google değil): router zaten NextDNS anycast'ini
  # (45.90.28.81 / 45.90.30.81) dağıtıyordu, yani filtre/log profili kullanımda.
  # 09 Ağu 2026'da ölçüldü — https://test.nextdns.io `"protocol": "UDP"` dedi:
  # profil çalışıyordu ama sorgular ŞİFRESİZ gidiyordu. DoH'u Cloudflare'e
  # kurmak şifrelerdi ama profili kaybettirirdi; NextDNS'in kendi DoH ucuna
  # bağlamak ikisini birden verir.
  #
  # TARİHÇE (08 Ağu 2026): bu blok system/net/dns.nix'ten buraya taşındı. O dosya
  # hiçbir import listesinde olmadığı için HİÇ eval edilmemişti ve üç ölümcül
  # hata taşıyordu — buraya hiçbiri geçmedi:
  #   (1) `services.resolved.dns` diye bir seçenek yok (şema settings.Resolve.*),
  #   (2) fallbackDns'e "1.1.1.1:53" yazılmış (resolved port kabul etmez),
  #   (3) minisign_key bozuktu → imza doğrulaması, dolayısıyla daemon çökerdi.
  #
  # BİRLEŞTİRME UYARISI: modülün upstreamDefaults=true varsayılanı üstakımın
  # example-dnscrypt-proxy.toml'unu bizim settings'imizin ALTINA koyar, ama
  # birleşme SIĞ (jq add) — burada tanımladığın her üst düzey anahtar üstakımın
  # aynı adlı tablosunu bütünüyle EZER. `sources` bunun en tehlikeli örneği.
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      # ⚠ 127.0.0.54 KULLANILAMAZ — systemd-resolved'in İKİNCİ dinleyicisi
      # (proxy stub) orada oturuyor. resolved .53 ile .54'ü BİRLİKTE tutar;
      # .54'e bind denemesi "listen udp4 127.0.0.54:53: bind: address already
      # in use" ile FATAL verir. 09 Ağu 2026'da ölçüldü: servis 5 kez restart
      # edip start-limit-hit'e girdi. Üstüne resolved'e DNS=127.0.0.54 demek
      # onu KENDİSİNE yöneltmek olur; döngüyü fark edip girdiyi sessizce
      # düşürür (resolvectl'de Global'de DNS Servers satırı hiç görünmez) ve
      # sorgular per-link DHCP DNS'ine kaçar → tüm zincir etkisiz kalır.
      # Bu yüzden ayrı bir loopback adresi: 127.0.0.2, standart 53 portu
      # (5353 SEÇME — mDNS orada).
      listen_addresses = [ "127.0.0.2:53" ];

      # Tek sunucu: NextDNS kişisel profili, statik DNS stamp ile.
      # dnscrypt ham DoH URL'si KABUL ETMEZ — sunucular yalnız stamp olarak
      # tanımlanır. Stamp elle üretildi (spesifikasyon: dnscrypt.info/stamps):
      #   0x02 (DoH) | props=1 (yalnız DNSSEC) | addr boş | hash yok
      #   | host "dns.nextdns.io" | path "/df5fa1"
      # Üretim sonrası geri çözülerek doğrulandı ve uca gerçek bir RFC8484
      # sorgusu atıldı → HTTP 200, NOERROR, 2 A kaydı (09 Ağu 2026).
      # Profil kimliğini değiştirirsen SADECE path değişir; stamp'i yeniden
      # üretmen gerekir, elle düzenlenemez (base64url gövdesi uzunluk-önekli).
      # NOT: df5fa1 bir parola değil ama bu dosya git'te — ele geçiren kişi
      # senin NextDNS profilin üzerinden sorgu yapıp log'unu kirletebilir.
      server_names = [ "nextdns-df5fa1" ];
      static."nextdns-df5fa1".stamp =
        "sdns://AgEAAAAAAAAAAAAOZG5zLm5leHRkbnMuaW8HL2RmNWZhMQ";

      # Üstakımın resolver listesini indirmesini BİLEREK kapatıyoruz (boş tablo
      # üstakımınkini ezer — yukarıdaki sığ birleşme uyarısı burada işimize
      # yarıyor). Statik stamp varken listeye ihtiyaç yok, ve indirme gerçek bir
      # arıza kaynağı: dnscrypt boot'ta raw.githubusercontent.com'dan ~2MB
      # public-resolvers.md çekip minisign ile doğrulamaya çalışır — TR'de tam
      # da engellenmeye aday bir host. Restart=always ile birleşince döngü olur.
      sources = { };

      # Bootstrap: DoH sunucusunun ADINI çözmek için gereken ilk sorgu. Doğrudan
      # IP verildiği için burada tavuk-yumurta yok ve SNI de yok → DPI bu ilk
      # temasta engelleyecek bir isim göremez.
      bootstrap_resolvers = [ "1.1.1.1:53" "8.8.8.8:53" ];

      # DNSSEC kapalı — core.nix'teki resolved ayarıyla aynı gerekçe: katılık
      # captive portal ve bazı yanlış imzalanmış alan adlarını kırıyor.
      require_dnssec = false;
      # İkisi de FALSE olmak ZORUNDA: NextDNS tanımı gereği filtreler (reklam/
      # izleyici engelleme, zaten istediğimiz şey) ve panelde log tutar. true
      # bırakılırsa dnscrypt kendi sunucusunu bu ölçütlerle eleyip elinde hiç
      # sunucu kalmadan başlar. Stamp'in props'u da (yalnız DNSSEC biti) bu
      # gerçeği dürüstçe bildiriyor.
      require_nolog = false;
      require_nofilter = false;

      # Kendi önbelleği; resolved da önbellekliyor ama bu negative caching ve
      # min-TTL biliyor → tekrar sorgular ağa hiç çıkmaz.
      cache = true;
      cache_size = 4096;
      cache_min_ttl = 600;
      cache_max_ttl = 86400;

      # IPv6 yok bu hatta; zapret de IPv4-only filtreliyor.
      block_ipv6 = true;

      # Yalnız hatalar — journal'ı şişirmesin.
      log_level = 0;
    };
  };

  # resolved'in upstream'i artık dnscrypt. DNS= satırını resolved modülü
  # networking.nameservers'tan besliyor; dnscrypt modülü buraya mkDefault ile
  # 127.0.0.1 koyuyor (orada kimse dinlemiyor) — bu tanım onu eziyor.
  networking.nameservers = [ "127.0.0.2" ];

  # `~.` = "HER alan adı için global DNS'i kullan". BU SATIR OLMAZSA tüm kurulum
  # boşa gider: NetworkManager DHCP'den aldığı per-link DNS'i (operatörün
  # sunucusunu) resolved'e yazar, resolved per-link'i global'e TERCİH eder ve
  # sorgular yine düz UDP/53 ile operatöre gider → hijack ayakta kalır.
  # BEDELİ: captive portal (otel/havalimanı WiFi) tam olarak DNS hijack'iyle
  # çalışır; bu satır varken portal sayfası açılmaz. Gezerken geçici kaldır.
  services.resolved.settings.Resolve.Domains = [ "~." ];

  # blockcheck — elle çağrılır, sudo blockcheck example.com.
  environment.systemPackages = [ zapret ];
}
