#!/usr/bin/env bash
# verify-context.sh — ağacı ÇALIŞTIRARAK sınar: iki eval + statix + deadnix.
# Metin/grep tabanlı denetim bilerek yok: yalnız eval'in çürütemediği bulgu gerçektir.
# Çıkış: 0 = hepsi geçti, 1 = en az bir kontrol düştü.

set -uo pipefail   # -e YOK: kontroller tek tek raporlanmalı, ilkinde durmamalı

FLAKE="${FLAKE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$FLAKE"

# deadnix'in tek izinli istisnası: üretilmiş hardware-configuration.nix.
DEADNIX_ALLOWED="./hardware-configuration.nix"

# Eksik araç "geçti" sayılmasın: sert düş.
missing=""
for dep in nix statix deadnix; do
    command -v "$dep" >/dev/null 2>&1 || missing="$missing $dep"
done
if [ -n "$missing" ]; then
    printf 'ÖN KONTROL DÜŞTÜ — PATH\x27te bulunamayan araç(lar):%s\n' "$missing" >&2
    printf 'Hepsi configuration.nix systemPackages\x27ta tanımlı; eksikse switch gerekiyor.\n' >&2
    exit 1
fi
# jq yalnız bilgi amaçlı "zemin" satırında kullanılır.

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
head_ "deadnix (izinli tek istisna: $DEADNIX_ALLOWED)"

# Dizin argümanı --exclude'dan ÖNCE: --exclude variadic, sonrasını da yutar.
dn_out=$(deadnix --fail . --exclude "$DEADNIX_ALLOWED" 2>&1)
if [ $? -eq 0 ]; then
    ok "izinli dosya dışında bulgu yok"
else
    bad "yeni ölü kod bulgusu (izinli dosya hariç):"
    printf '%s\n' "$dn_out" | sed 's/^/       /' | head -30
fi

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
