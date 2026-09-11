#!/usr/bin/env bash
# verify-dlss-dll.sh — bir nvngx_dlss*.dll'in GERÇEKTEN NVIDIA'dan gelip
# gelmediğini kanıtlar. "İnternetten indirdiğim DLSS DLL'i güvenli mi?" sorusunun
# tek nesnel cevabı budur: Authenticode imzası.
#
# Neden bu araca ihtiyaç var (2 Eyl 2026): "sızan DLSS DLL'i" PC oyun dünyasının
# en verimli zararlı-yazılım dağıtım kanalı. Dosya adının, boyutun ya da forum
# gönderisinin hiçbir kanıt değeri yok. NVIDIA nvngx_dlss.dll'i DigiCert
# sertifikasıyla İMZALAR; gerçek bir sızıntı bile imzalıdır (sızan şey NVIDIA'nın
# kendi DVS derlemesidir). Yeniden paketlenmiş/truva atı bir DLL imzayı
# GEÇEMEZ — imzalama anahtarı NVIDIA'da.
#
# Kullanım:  bash scripts/verify-dlss-dll.sh <yol/nvngx_dlss.dll> [...]
# Çıkış kodu: hepsi geçerse 0, herhangi biri kalırsa 1.
#
# Araçlar bu flake'in PİNLİ nixpkgs'inden gelir (registry'den DEĞİL — CLAUDE.md
# "Lint / inspection tooling" kuralı). İlk çalıştırmada indirir, sonra cache'ten.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_URL="https://loathingkernel.github.io/proton-upscalers/manifest.json"

if [ "$#" -eq 0 ]; then
  echo "kullanım: bash scripts/verify-dlss-dll.sh <nvngx_dlss.dll> [...]" >&2
  exit 2
fi

echo "== araçlar (pinli nixpkgs'ten)"
TOOLS=$(nix build --no-link --print-out-paths --impure --expr \
  "let f = builtins.getFlake \"$REPO\";
       p = f.inputs.nixpkgs.legacyPackages.\${builtins.currentSystem};
   in p.buildEnv { name = \"dlss-verify-tools\"; paths = [ p.osslsigncode p.exiftool ]; }" 2>/dev/null | tail -1)
if [ -z "$TOOLS" ] || [ ! -x "$TOOLS/bin/osslsigncode" ]; then
  echo "  [HATA] osslsigncode/exiftool kurulamadı" >&2; exit 1
fi
echo "  $TOOLS"

# Bilinen sürüm listesi — Proton-CachyOS'un protonfixes'inin kullandığı manifest.
# Ağ yoksa bu adım atlanır, imza kontrolü yine de yapılır (asıl kanıt odur).
MF=$(mktemp); trap 'rm -f "$MF"' EXIT
if curl -fsS --max-time 15 "$MANIFEST_URL" -o "$MF" 2>/dev/null; then
  echo "== manifest indirildi ($(wc -c < "$MF") bayt)"
else
  echo "== manifest indirilemedi — MD5 çapraz kontrolü atlanacak"; : > "$MF"
fi

RC=0
for F in "$@"; do
  echo
  echo "──────────────────────────────────────────────────────────────"
  echo "DOSYA: $F"
  if [ ! -f "$F" ]; then echo "  [KALDI] dosya yok"; RC=1; continue; fi

  VER=$("$TOOLS/bin/exiftool" -s3 -ProductVersion "$F" 2>/dev/null | tr ',' '.')
  DESC=$("$TOOLS/bin/exiftool" -s3 -FileDescription "$F" 2>/dev/null)
  CO=$("$TOOLS/bin/exiftool" -s3 -CompanyName "$F" 2>/dev/null)
  MD5=$(md5sum "$F" | cut -d' ' -f1 | tr 'a-f' 'A-F')
  echo "  sürüm     : ${VER:-<yok>}"
  echo "  açıklama  : ${DESC:-<yok>}"
  echo "  şirket    : ${CO:-<yok>}"
  echo "  MD5       : $MD5"

  # --- 1) ASIL KANIT: Authenticode imzası geçerli mi ve imzalayan NVIDIA mı? ---
  OUT=$("$TOOLS/bin/osslsigncode" verify "$F" 2>&1)
  if grep -q "Signature verification: ok" <<<"$OUT" \
     || grep -qi "Succeeded" <<<"$OUT"; then SIGOK=1; else SIGOK=0; fi
  if grep -q "Subject: CN=NVIDIA Corporation" <<<"$OUT"; then NVOK=1; else NVOK=0; fi

  if [ "$SIGOK" = 1 ] && [ "$NVOK" = 1 ]; then
    echo "  imza      : [GEÇTİ] geçerli + imzalayan CN=NVIDIA Corporation"
  elif [ "$NVOK" = 1 ]; then
    echo "  imza      : [ŞÜPHELİ] NVIDIA imzalı görünüyor ama doğrulama tam geçmedi"
    echo "$OUT" | grep -iE "error|fail|mismatch|expired|revok" | sed 's/^/              /' | head -5
    RC=1
  else
    echo "  imza      : [KALDI] NVIDIA imzası YOK — BU DOSYAYI KULLANMA"
    echo "$OUT" | tail -3 | sed 's/^/              /'
    RC=1
  fi

  # --- 2) Yardımcı: bilinen bir yayına mı denk geliyor? ---
  if [ -s "$MF" ]; then
    # NOT: manifestte md5_hash'i string OLMAYAN girdiler var → ascii_upcase patlıyor
    # ("explode input must be a string") ve TÜM ifade iptal olup sessizce boş
    # dönüyordu, yani her dosya yanlışlıkla "bilinmiyor" görünüyordu. Tip guard'ı şart.
    HIT=$(jq -r --arg m "$MD5" '
          [ .[][]? | select(type=="object")
                   | select((.md5_hash|type)=="string")
                   | select((.md5_hash|ascii_upcase) == $m) ]
          | if length==0 then ""
            else .[0] | "\(.version)  dev=\(.is_dev_file)  imza_geçerli=\(.is_signature_valid)  \(.signed_datetime)"
            end' "$MF" 2>/dev/null)
    if [ -n "$HIT" ]; then
      echo "  manifest  : BULUNDU → $HIT"
    else
      echo "  manifest  : bu MD5 bilinen yayınlarda YOK"
      echo "              (imza geçtiyse yeni/dev bir derleme olabilir; geçmediyse tehlike)"
    fi
  fi
done

echo
if [ "$RC" = 0 ]; then echo "SONUÇ: tüm dosyalar NVIDIA imzalı."; else echo "SONUÇ: EN AZ BİR DOSYA KALDI — yukarı bak."; fi
exit "$RC"
