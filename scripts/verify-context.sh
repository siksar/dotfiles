#!/usr/bin/env bash
#
# verify-context.sh — bu ağaç hakkındaki iddiaları ÇALIŞTIRARAK sınar.
#
# Neden var: 15 Ağu 2026'da context denetiminde metinsel/regex çıkarımla 31 bulgu
# üretildi, gerçek olan 0 çıktı (regex `../../lib/x` içinden `./../lib/x` yakaladı,
# prose'daki `power.nix` kısaltması ölü yol sanıldı). Ayıklayan tek şey eval oldu.
# Bu yüzden buraya YALNIZ çalıştıran kontroller girer — grep tabanlı doküman
# denetimi bilerek yoktur, o kendisi bir halüsinasyon kaynağıdır.
#
# Yakaladığı sınıf: yetim modül, uydurulmuş option adı, ölü ./ referansı, lint
# gerilemesi. `nix-instantiate --parse` hook'u bunların hiçbirini göremez —
# uydurulmuş bir option adı sözdizimsel olarak kusursuzdur (bkz. commit 8a0565a,
# hiç eval edilmemiş dns.nix + var olmayan services.resolved.dns).
#
# Kullanım:  bash scripts/verify-context.sh
# Çıkış:     0 = her şey yerinde, 1 = en az bir kontrol düştü

set -uo pipefail   # -e YOK: kontroller tek tek raporlanmalı, ilkinde durmamalı

FLAKE="${FLAKE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$FLAKE"

# deadnix'in tek izinli istisnası: üretilmiş hardware-configuration.nix (`pkgs` hit'i).
# Yeni bir bulgu çıkarsa bu listeye EKLEME — bulguyu düzelt.
# (Eski `DEADNIX_BASELINE=1` sayacı 25 Ağu 2026'da kaldırıldı; gerekçe 4. kontrolde.)
DEADNIX_ALLOWED="./hardware-configuration.nix"

# ── Ön kontrol: bağımlılıklar ─────────────────────────────────────────────────
# 25 Ağu 2026'da öğrenildi: jq sistemde kurulu DEĞİLDİ ve aşağıdaki deadnix sayımı
# `2>/dev/null || echo 0` ile hatayı yutup "0 hit" raporladı. Sonuç: temel çizgi
# kontrolü DÜŞTÜ ama gerekçe uyduruktu — ağaçta hiçbir sorun yoktu. Eksik bir araç
# YANLIŞ bir sonuca değil, GÜRÜLTÜLÜ bir hataya dönüşmeli; sessizce yanlış cevap
# veren bir kapı, kapı olmamasından kötüdür (bu script'in var oluş gerekçesiyle
# aynı kural — bkz. yukarıdaki 31-yanlış-bulgu notu).
# SERT bağımlılıklar = kontrolü fiilen YAPAN araçlar. Biri yoksa o kontrol
# yapılamaz, yapılamayan kontrol "geçti" sayılamaz → sert düş.
missing=""
for dep in nix statix deadnix; do
    command -v "$dep" >/dev/null 2>&1 || missing="$missing $dep"
done
if [ -n "$missing" ]; then
    printf 'ÖN KONTROL DÜŞTÜ — PATH\x27te bulunamayan araç(lar):%s\n' "$missing" >&2
    printf 'Hepsi configuration.nix systemPackages\x27ta tanımlı; eksikse switch gerekiyor.\n' >&2
    exit 1
fi
# jq SERT DEĞİL: artık yalnız aşağıdaki bilgi amaçlı "zemin" satırında kullanılıyor
# (deadnix sayımı jq'suz yeniden yazıldı). Yokluğu bir kontrolü düşürmez, sadece o
# satırı işaretler — bir kapı, tuttuğu kontrolle ilgisi olmayan bir aracın yokluğu
# yüzünden tüm işi bloklamamalı.

fail=0
ok()   { printf '  [ OK ] %s\n' "$1"; }
bad()  { printf '  [HATA] %s\n' "$1"; fail=1; }
head_(){ printf '\n== %s\n' "$1"; }

warn_sys=$(mktemp); warn_hm=$(mktemp)
trap 'rm -f "$warn_sys" "$warn_hm"' EXIT

############################
# 1-2. Canlı eval — tek belirleyici kanıt
############################
head_ "eval (yetim modül / uydurma option / ölü referans kapısı)"

sys_drv=$(nix eval --raw \
    .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath \
    2>"$warn_sys") \
  && ok "sistem değerleniyor" \
  || { bad "sistem EVAL DÜŞTÜ"; sed 's/^/       /' "$warn_sys" | tail -20; }

hm_drv=$(nix eval --raw \
    '.#homeConfigurations."zixar".activationPackage.drvPath' \
    2>"$warn_hm") \
  && ok "home-manager değerleniyor" \
  || { bad "HM EVAL DÜŞTÜ"; sed 's/^/       /' "$warn_hm" | tail -20; }

############################
# 3. statix — çıktısı boş olmalı
############################
head_ "statix (statix.toml filtreli: repeated_keys + empty_pattern kapalı)"

statix_out=$(statix check . 2>&1)
if [ -z "$statix_out" ]; then
    ok "temiz"
else
    bad "uyarı üretti:"
    printf '%s\n' "$statix_out" | sed 's/^/       /' | head -30
fi

############################
# 4. deadnix — izinli dosya DIŞINDA hiç bulgu olmamalı
############################
# 25 Ağu 2026'da jq'suz yeniden yazıldı. Eskiden `deadnix -o json | jq | length`
# ile hit SAYILIR, sonuç DEADNIX_BASELINE ile karşılaştırılırdı. İki kusuru vardı:
#   1. jq yoksa `|| echo 0` sayımı sessizce 0 yapıyor, kontrol UYDURUK bir
#      gerekçeyle düşüyordu (jq o gün sistemde kurulu değildi).
#   2. Sayıya bağlamak yanlış yöndü: hardware-configuration.nix'teki tek bulgu bir
#      gün ÇÖZÜLÜRSE (iyi bir şey) sayım 0'a düşer ve kapı bunu GERİLEME sanardı.
# Asıl niyet zaten "izinli dosya dışında yeni bulgu olmasın" — `--fail --exclude`
# tam olarak bunu söylüyor, hiçbir yardımcı araca ihtiyaç duymadan, ve hata
# çıktısını deadnix'in kendi okunur formatı veriyor.
head_ "deadnix (izinli tek istisna: $DEADNIX_ALLOWED)"

# ARGÜMAN SIRASI ZORUNLU: `--exclude` VARIADIC (`<EXCLUDES>...`), yani
# `--exclude X .` yazarsan `.` da bir istisna olarak yutulur → hiçbir dosya
# taranmaz → kapı HER ZAMAN yeşil yanar. Bu tam olarak 25 Ağu 2026'da oldu ve
# ancak kasıtlı ölü kod enjekte eden bir negatif test yakaladı. Dizin argümanı
# `--exclude`'dan ÖNCE gelmeli.
dn_out=$(deadnix --fail . --exclude "$DEADNIX_ALLOWED" 2>&1)
if [ $? -eq 0 ]; then
    ok "izinli dosya dışında bulgu yok"
else
    bad "yeni ölü kod bulgusu (izinli dosya hariç):"
    printf '%s\n' "$dn_out" | sed 's/^/       /' | head -30
fi

# nixfmt BİLEREK çağrılmıyor: ağaç genelinde çalıştırmak elle hizalanmış
# yorum sütunlarını siler (CLAUDE.md kuralı).

############################
# 5. Eval uyarıları — düşmez ama görünür kalmalı
############################
warns=$(sort -u "$warn_sys" "$warn_hm" | grep -c 'evaluation warning' 2>/dev/null || true)
if [ "${warns:-0}" -gt 0 ]; then
    head_ "eval uyarıları ($warns adet — hata değil, eskime sinyali)"
    sort -u "$warn_sys" "$warn_hm" | grep 'evaluation warning' | sed 's/^/  /' | head -15
fi

############################
# 6. Tarihli zemin — iddia değil, ölçüm
############################
head_ "zemin ($(date +%Y-%m-%d\ %H:%M))"
printf '  %-12s %s\n' \
  "nixpkgs"   "$(command -v jq >/dev/null 2>&1 \
                 && nix flake metadata --json 2>/dev/null | jq -r '.locks.root as $r | .locks.nodes[.locks.nodes[$r].inputs.nixpkgs].locked.rev' | cut -c1-12 \
                 || echo '(jq yok — bilgi satırı atlandı)')" \
  "cosmic-comp" "$(nix eval --raw .#nixosConfigurations.nixos.pkgs.cosmic-comp.version 2>/dev/null || echo '?')" \
  "kernel"    "$(uname -r)" \
  "sistem"    "$(basename "${sys_drv:-?}")" \
  "hm"        "$(basename "${hm_drv:-?}")"

############################
# Sonuç
############################
if [ "$fail" -eq 0 ]; then
    printf '\nTÜM KONTROLLER GEÇTİ.\n'
else
    printf '\nEN AZ BİR KONTROL DÜŞTÜ — yukarıdaki [HATA] satırlarına bak.\n'
fi
exit "$fail"
