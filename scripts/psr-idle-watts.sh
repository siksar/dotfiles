#!/usr/bin/env bash
# Statik ekranda (PSR aktifken) güç ölçümü — ort/min/maks + PSR kanıtı.
#
# NEDEN BU DOSYA: power-audit.sh envanter döker, idle-baseline.sh 120 s
# sakinleşmeli uzun tabanı alır. Bu script tek bir soruyu yanıtlar: "ekran
# gerçekten statikken, PSR gerçekten içerideyken makine kaç watt çekiyor?"
# PSR'nin o pencerede aktif OLDUĞUNU da kanıtlar — yoksa ölçtüğün sayı
# PSR'siz bir sayıdır ve adı yanlış olur.
#
# TASARIM KISITI — ölçüm penceresinde HİÇBİR ŞEY YAZDIRMAZ ve fork ETMEZ:
#   · Ekrana tek karakter basmak terminali yeniden çizdirir → PSR anında çıkar.
#     Bu ölçümü bozmakla kalmaz, ölçmek istediğin şeyi yok eder.
#   · Örnekleme saf bash tamsayı aritmetiğiyle (µA × µV = pW, 64-bit'e sığar),
#     bekleme `read -t` ile yapılır. Döngüde ne awk, ne cat, ne sleep çağrısı var.
#   · Bütün çıktı ölçüm bittikten SONRA basılır.
#
# KULLANIM:
#   sudo bash scripts/psr-idle-watts.sh          # PSR kanıtıyla (debugfs root ister)
#   bash scripts/psr-idle-watts.sh               # PSR'siz, yalnız watt
#
#   Enter'a bastıktan sonra LEAD saniyen var: terminali başka bir workspace'e
#   at ya da pencereyi küçült, sonra DOKUNMA. Fare kıpırtısı, yanıp sönen imleç,
#   tikleyen bir saat — üçü de PSR'yi dışarı atar.
#
# AYARLAR (ortam değişkeni):
#   DUR=30    ölçüm süresi (s)        LEAD=10  ekranı boşaltman için tanınan süre
#   IVL=1     örnekleme aralığı (s)   NOPSR=1  PSR örneklemesini kapat (perturbasyon A/B'si)
set -u

DUR=${DUR:-30}; IVL=${IVL:-1}; LEAD=${LEAD:-10}; NOPSR=${NOPSR:-0}; PSRPOLL=${PSRPOLL:-0}
st_a=?; st_b=?

BAT=/sys/class/power_supply/BAT1
GPU=/sys/class/drm/card1/device/gpu_busy_percent
PSRDIR=/sys/kernel/debug/dri/0000:65:00.0/eDP-1

# --- ön koşullar -----------------------------------------------------------
[[ -r $BAT/current_now ]] || { echo "HATA: $BAT okunamıyor" >&2; exit 1; }
read -r ACON < /sys/class/power_supply/ACAD/online
read -r BSTAT < $BAT/status
if [[ $ACON != 0 ]]; then
  echo "HATA: fiş takılı. current_now şarj akımını gösterir, tüketimi değil." >&2
  echo "      Fişi çek ve tekrar dene (durum: $BSTAT)." >&2
  exit 1
fi

PSR=1
[[ $NOPSR == 1 ]] && PSR=0
[[ $PSR == 1 && ! -r $PSRDIR/psr_state ]] && {
  echo "not: debugfs okunamıyor (root değilsin?) — PSR kanıtı olmadan devam." >&2
  PSR=0
}

# --- fork'suz bekleme: tek seferlik bir boru aç, read -t üzerinden beklet ----
# `sleep` harici bir komut; saniyede bir fork+exec demek. Bunun yerine hiçbir
# zaman veri gelmeyecek bir fd'de zaman aşımına düşüyoruz: sıfır fork.
exec {NAP}< <(exec tail -f /dev/null)
nap() { read -t "$1" -u "$NAP" _ 2>/dev/null || true; }

N=$(( DUR / IVL ))
(( N > 0 )) || { echo "HATA: DUR/IVL en az 1 örnek vermeli" >&2; exit 1; }

# --- kullanıcıya süre tanı, sonra sus --------------------------------------
cat <<EOF
PSR statik-ekran güç ölçümü
  süre       : ${DUR}s  (${N} örnek, ${IVL}s aralık)
  PSR kanıtı : $( ((PSR)) && echo "açık" || echo "KAPALI" )
  ŞİMDİ: terminali gizle / başka workspace'e geç ve ${LEAD}s içinde dokunmayı bırak.
EOF
nap "$LEAD"

# --- ölçüm penceresi: buradan sonra tek karakter basılmaz -------------------
declare -a MW STATES
gsum=0; gn=0
psr_a=0; psr_b=0
((PSR)) && { read -r psr_a < "$PSRDIR/psr_residency"; read -r st_a < "$PSRDIR/psr_state"; }

for ((i=0; i<N; i++)); do
  read -r c < $BAT/current_now
  read -r v < $BAT/voltage_now
  MW+=( $(( c * v / 1000000000 )) )          # µA×µV = pW → /1e9 = mW
  if read -r g < $GPU 2>/dev/null; then gsum=$((gsum+g)); gn=$((gn+1)); fi
  # psr_state POLL'U VARSAYILAN OLARAK KAPALI (27 Ağu 2026). Sürücüde bu dosyanın
  # okuması, okumadan ÖNCE `dc_allow_idle_optimizations(dc, false)` çağırıyor —
  # yani her poll idle optimizasyonlarını kapatıyor ve ölçtüğün şeyi yok ediyor.
  # Saniyede bir okumak ölçümü yukarı taşır. PSRPOLL=1 ile açılabilir, ama o zaman
  # aldığın watt rakamı "PSR poll edilirken" rakamıdır, temiz taban DEĞİLDİR.
  if ((PSR)) && ((PSRPOLL)); then read -r s < "$PSRDIR/psr_state" 2>/dev/null && STATES+=("$s"); fi
  nap "$IVL"
done

((PSR)) && { read -r psr_b < "$PSRDIR/psr_residency"; read -r st_b < "$PSRDIR/psr_state"; }
exec {NAP}<&-

# --- rapor (ölçüm bitti, artık yazmak serbest) ------------------------------
min=${MW[0]}; max=${MW[0]}; sum=0
for m in "${MW[@]}"; do
  (( m < min )) && min=$m
  (( m > max )) && max=$m
  sum=$(( sum + m ))
done
avg=$(( sum / ${#MW[@]} ))

w() { printf '%d.%02d W' $(( $1 / 1000 )) $(( $1 % 1000 / 10 )); }

echo
echo "── sonuç ────────────────────────────────────────────"
printf 'ortalama   : %s\n' "$(w $avg)"
printf 'minimum    : %s\n' "$(w $min)"
printf 'maksimum   : %s\n' "$(w $max)"
printf 'yayılım    : %s  (maks-min)\n' "$(w $(( max - min )) )"
printf 'örnek      : %d adet / %ds\n' "${#MW[@]}" "$DUR"
# Yayılım = ölçümün KALİTE göstergesi. Taban gerçekten sabittir; büyük bir maks
# arka planda bir şeyin uyandığı anlamına gelir ve ORTALAMAYI yukarı çeker, tabanı
# değil. Bu yüzden kirli koşuda güvenilecek sayı ortalama değil minimumdur.
# Eşikler 27 Ağu 2026'da altı koşuluk seriden: temiz koşularda yayılım 0.67-0.85 W,
# kirlilerde 3.2-7.5 W çıktı — arada boşluk var, sınır keyfi değil.
if   (( max - min < 1500 )); then echo 'kalite     : TEMİZ — ortalama güvenilir'
elif (( max - min < 3000 )); then echo 'kalite     : sınırda — arka planda kıpırtı var, minimuma bak'
else echo 'kalite     : KİRLİ — pencerede bir şey çalıştı; ortalamayı KULLANMA, minimumu al'
fi
(( gn > 0 )) && printf 'gpu_busy   : %%%d ortalama\n' $(( gsum / gn ))

if ((PSR)); then
  echo
  echo "── PSR kanıtı ───────────────────────────────────────"
  # psr_residency BİRİKMELİ BİR SAYAÇ DEĞİL (27 Ağu 2026, ölçüldü): okuma onu
  # sıfırlıyor ve değer yalnız PSR'den ÇIKILDIĞINDA yazılıyor — yani "tamamlanmış
  # son oturumun süresi". Pencere boyunca PSR hiç çıkmazsa sonda 0 okunur.
  # Bu yüzden delta almak anlamsız (negatif çıkar); ham iki okuma basılıyor ve
  # asıl kanıt aşağıdaki durum histogramı. sonra=0 + durumlar hep 6 = EN İYİ sonuç:
  # PSR pencere boyunca hiç kesilmemiş.
  printf 'residency  : önce=%s sonra=%s  (okuma sayacı sıfırlar; delta anlamsız)\n' \
         "$psr_a" "$psr_b"
  # Pencere içi poll YOK (bkz. döngüdeki not): başta ve sonda birer okuma. sonra=6
  # + residency sonra=0 = PSR pencere boyunca hiç kesilmemiş.
  printf 'psr_state  : önce=%s sonra=%s  (pencere içinde poll edilmedi)\n' "$st_a" "$st_b"
  if (( ${#STATES[@]} == 0 )); then
    echo "durumlar   : (psr_state okunamadı — yalnız residency güvenilir)"
  else
  # Ham durum histogramı. Enum'u yorumlamıyoruz: DC/DMUB sürüm sürüm değişiyor,
  # bu makinede 0 = PSR dışı, 6 = PSR_STATE3 (panel kendini tazeliyor) gözlendi.
  # Sayılar konuşsun; tek bir değeri "aktif" diye sabitlemek yanlış olur.
  printf 'durumlar   :'
  printf '%s\n' "${STATES[@]}" | sort -n | uniq -c | while read -r n s; do
    printf ' %s×%d' "$s" "$n"
  done
  echo
  act=$(printf '%s\n' "${STATES[@]}" | grep -cv '^0$')
  printf 'PSR dışı   : %d/%d örnek state=0\n' $(( ${#STATES[@]} - act )) "${#STATES[@]}"
  if (( act == 0 )); then
    echo
    echo "UYARI: hiçbir örnekte PSR'ye girilmemiş. Ekran statik değildi —"
    echo "       görünür bir imleç/saat/animasyon var. Bu sayı PSR'li DEĞİL."
  fi
  fi
fi

echo
echo "── koşullar ─────────────────────────────────────────"
read -r bl < /sys/class/backlight/amdgpu_bl1/brightness
read -r blm < /sys/class/backlight/amdgpu_bl1/max_brightness
read -r pp < /sys/firmware/acpi/platform_profile
read -r cap < /sys/class/power_supply/BAT1/capacity
printf 'parlaklık  : %d/%d  (%%%d)\n' "$bl" "$blm" $(( bl * 100 / blm ))
printf 'profil     : %s   pil: %%%s\n' "$pp" "$cap"
printf 'oturum     : %s\n' "${XDG_CURRENT_DESKTOP:-?}"
