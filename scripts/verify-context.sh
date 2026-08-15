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

# deadnix temel çizgisi: üretilmiş hardware-configuration.nix'teki tek `pkgs` hit'i.
# Yeni bir bulgu çıkarsa bu sayıyı YÜKSELTME — bulguyu düzelt.
DEADNIX_BASELINE=1
DEADNIX_ALLOWED="./hardware-configuration.nix"

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
# 4. deadnix — tam olarak temel çizgi kadar hit
############################
head_ "deadnix (temel çizgi: $DEADNIX_BASELINE hit, yalnız $DEADNIX_ALLOWED)"

dn_json=$(deadnix -o json . 2>/dev/null || true)
dn_count=$(printf '%s' "$dn_json" | jq -s '[.[].results[]] | length' 2>/dev/null || echo 0)
dn_files=$(printf '%s' "$dn_json" | jq -rs '.[].file' 2>/dev/null | sort -u)

if [ "$dn_count" -eq "$DEADNIX_BASELINE" ] && [ "$dn_files" = "$DEADNIX_ALLOWED" ]; then
    ok "temel çizgide ($dn_count hit)"
else
    bad "temel çizgiden sapma: $dn_count hit, dosyalar: ${dn_files:-yok}"
    printf '%s\n' "$dn_json" | jq -r 'select(.file != "'"$DEADNIX_ALLOWED"'")
        | .file as $f | .results[] | "       \($f):\(.line) \(.message)"' 2>/dev/null
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
  "nixpkgs"   "$(nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes.nixpkgs.locked.rev' | cut -c1-12)" \
  "hyprland"  "$(nix eval --raw .#nixosConfigurations.nixos.pkgs.hyprland.version 2>/dev/null || echo '?')" \
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
