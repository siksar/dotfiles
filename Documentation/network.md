# Ağ — sansür aşma (zapret + DoH), çekirdek ağ yığını

*Durum: 28 Eyl 2026. Modüller: `system/net/` — `censorship.nix`, `core.nix`,
`vpn.nix` (Mullvad, devre dışı), `geoclue.nix`, `localsend.nix`.*

Tarihli ölçümler ve olay kayıtları (en yeni üstte). Kural ve tuzak uyarıları
ilgili `.nix` yorumlarında.

---

## 28 Eyl 2026 — DoH sunucusu NextDNS → Cloudflare

**Tetik:** Varia, SteamRIP'in BuzzHeavier linkinden hiçbir şey indirmiyordu.
`ts.bzzhr.to` yerelde `0.0.0.0`'a çözülüyordu; NextDNS'in JSON cevabında
`EDE 17 (Filtered): Blocked by NextDNS: ai-threat-detection`. Cloudflare aynı
adı `burritoflakes.com` CNAME'i üzerinden 104.26.x.x'e çözdü. Profil `df5fa1`'in
panel parolası elde olmadığı için allowlist'e eklemek mümkün değildi.

**Gecikme ölçümü** (curl, tek bağlantı üzerinden art arda 6 sorgu, JSON DoH;
ilk sayı TLS el sıkışması dahil):

| Sunucu | 1. sorgu | sonrakiler |
|---|---|---|
| Cloudflare `cloudflare-dns.com` | 0,85 s | 0,09–0,18 s |
| NextDNS `dns.nextdns.io/df5fa1` | 2,21 s | 0,19–0,76 s |
| Mullvad `dns.mullvad.net` | 1,76 s | 0,40–0,61 s |

(Google, Quad9, AdGuard JSON sorgusunu kabul etmedi — ölçüm dışı, istek
biçimi sorunu, sunucu sorunu değil.)

**Stamp:** Cloudflare için iki stamp (addr 1.1.1.1 ve 1.0.0.1, host
`cloudflare-dns.com`, path `/dns-query`, props=7) aynı bash üretecinden çıktı;
üreteç eski NextDNS stamp'ini bayt bayt aynen üreterek doğrulandı.

**Yan bulgu (Varia):** Varia linki aria2'ye vermeden önce `requests.head(url)`
atar (`download/thread.py:124`, zaman aşımı ve hata yakalama yok). Host
çözülemeyince iş parçacığı sessizce ölür; arayüzde hata yok, yalnız
`journalctl --user` içinde traceback.

---

## 09 Ağu 2026 — Şifreli DNS (DoH) devreye alındı: ölçümler

Zincir ve gerekçe: `system/net/censorship.nix` "2. KOL — ŞİFRELİ DNS" bloğu.

### test.nextdns.io — öncesi / sonrası

- **Öncesi (düz UDP):** router NextDNS anycast'ini (45.90.28.81 / 45.90.30.81)
  dağıtıyordu. https://test.nextdns.io yanıtı `"protocol": "UDP"` dedi — profil
  kullanımdaydı ama sorgular ŞİFRESİZ gidiyordu. Yanıtta `"profile"` alanı
  YOKTU → sorgular o dönem profile atanmıyordu, filtreler muhtemelen
  uygulanmıyordu.
- **Sonrası (DoH):** `"protocol": "DOH"`, profil atanıyor, PoP `edgeuno-ist-1`,
  DoH el sıkışması 69 ms — DoH profili de devreye soktu.

### dnscrypt-proxy 127.0.0.54 çakışması (1. deneme)

İlk switch'te `listen_addresses = [ "127.0.0.54:53" ]` denendi. systemd-resolved
.53 ile .54'ü (proxy stub) birlikte tuttuğu için bind
`listen udp4 127.0.0.54:53: bind: address already in use` ile FATAL verdi;
servis **5 kez restart edip start-limit-hit'e girdi**. Çözüm 127.0.0.2:53
(uyarının tam metni `listen_addresses` satırının üstünde).

### DNS stamp doğrulaması

Elle üretilen `sdns://` stamp'i (NextDNS profil `df5fa1`) geri çözülerek
doğrulandı ve uca gerçek bir RFC8484 sorgusu atıldı → **HTTP 200, NOERROR,
2 A kaydı**.

---

## 02–09 Ağu 2026 — Olay: nfqws bir hafta fiilen ölüydü (NRestarts)

nfqws `initgroups: Operation not permitted` ile **44.193 kez** üst üste çöktü;
zapret 02–09 Ağu arası fiilen çalışmıyordu. `Restart=on-failure` +
`RestartSec=3` yüzünden `systemctl is-active` "active" gösterdi. Kök neden: yetki düşürme (`--user`)
CAP_SETGID/CAP_SETUID olmadan. Kalıcı uyarı ve sağlık komutu
`censorship.nix`'te `systemd.services.zapret` `serviceConfig`'inin içinde.

---

## 01 Ağu 2026 — zapret strateji ölçümü (blockcheck)

Hedef: kara listedeki bir alan adı (pornhub.com). TR DPI'sı seçici olduğu için
serbest bir alan adıyla ölçmek doğrulama sayılmaz (uyarı `nfqwsArgs` üstünde).

TCP 80/443 için blockcheck'in WORKING bulduğu stratejiler:

| Strateji | Sonuç |
|---|---|
| `nfqws --dpi-desync=fake --dpi-desync-ttl=3` | WORKING |
| `nfqws --dpi-desync=fake --dpi-desync-fooling=ts` | WORKING |
| `fakedsplit --ttl=3 --split-pos=1` | WORKING |
| `hostfakesplit --ttl=3` | WORKING |

Seçilen: `fake`. HTTP (80) ve HTTPS (443) ikisinde de WORKING → tek profil.
Uygulanan argümanların tek kaynağı `censorship.nix`'teki `nfqwsArgs`; burada
kopyası tutulmaz (strateji paragrafı bir kez kodla ayrışıp hataya yol açmıştı).

---

## 18 Tem 2026 — NetworkManager-wait-online kapatıldı (boot ölçümü)

Servis boot'ta **~49 s** bekliyordu (eth + WiFi ikisi bağlıyken biri geç
DHCP/carrier alıyor) ve `network-online.target` → `graphical.target` zincirini
kilitliyordu. Giriş sonrası 10–20 s boş ekran (yanıp sönen imleç) tam olarak bu
beklemeydi. Kapatınca `graphical.target` ~3 s'de geldi → giriş anlık, boot ~49 s kısa.
Ayar: `system/net/core.nix` (`NetworkManager-wait-online.enable = false`).
