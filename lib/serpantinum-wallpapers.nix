# Serpantinum'un resmi duvar kağıdı deposu (github.com/ilyamiro/shell-wallpapers) —
# üstakım README'sinin "wallpapers are available in a separate repository" dediği depo.
# Depoda LICENSE yok; kaynak burada not ediliyor.
#
# NEDEN lib/: bu yolu İKİ ayrı eval bağlamı okuyor —
#   system/desktop/serpantinum.nix  → oturum sarmalayıcısının WALLPAPER_DIR'i + ilk
#                                     açılış matugen çağrısı
#   home/desktop/serpantinum/       → autostart.conf'un `awww img` ilk-açılış yedeği
# NixOS modülü ile HM modülü birbirini import EDEMEZ (kök CLAUDE.md'nin sert kuralı),
# o yüzden paylaşılan veri lib/'e düşer — lib/theme.nix, lib/gamerun.nix ile aynı
# `{ pkgs }:` çağrı sözleşmesi. İki taraf da aynı türetimi çözer, store'da tek kopya.
#
# BOYUT: 319 görsel / 429 MB, tek bir store yolu. Bilinçli bedel — alternatifi
# ~/Pictures altındaki elle klonlanmış (repo'da izi olmayan, taze kurulumda var
# olmayan) bir dizine bağımlı kalmaktı. Caelestia'nın kendi 16 küratörlü duvar kağıdı
# (lib/wallpapers/) bundan ETKİLENMEZ — ayrı dizin, ayrı görsel kimlik.
{ pkgs }:

let
  src = pkgs.fetchFromGitHub {
    owner = "ilyamiro";
    repo = "shell-wallpapers";
    rev = "4b940811d375a5553ac97ac8824e571b9a5bace7"; # "Update 30.04.26"
    hash = "sha256-NrH1W73djn0k5+aX7Zt1vmEThPXIgIwUM4plswMSKPc=";
  };
in
{
  inherit src;

  # SUPER+W seçicisinin tarayacağı dizin (WALLPAPER_DIR). `videos/` kapsam dışı —
  # gerekçe system/desktop/serpantinum.nix'teki export satırının yanında.
  imagesDir = "${src}/images";

  # Bu oturumun ilk açılış duvar kağıdı. lib/wallpapers/obsidian-dunes.jpg ile BAYT
  # BAYT AYNI dosya (15 Ağu sha256 ile doğrulandı: 5af5fb78…) — o zaten bu depodan
  # alınıp yeniden adlandırılmıştı. Adı burada TEK yerde duruyor çünkü iki taraf da
  # (sistem sarmalayıcısının matugen çağrısı + HM'nin autostart yedeği) aynı görseli
  # göstermek zorunda; iki dosyaya kopyalanırsa biri sessizce kayar.
  default = "${src}/images/desert-doom-sand-dunes-dark-background-monochrome-landscape-3440x1440-6409.jpg";
}
