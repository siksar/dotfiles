# ============================================================================
# GÜN 1: DEĞERLER VE TİPLER (Values & Types)
# ============================================================================
# Nix tamamen "expression" tabanlı bir dildir. Her şey bir ifadedir.
# Komut yok, döngü yok, mutation yok — sadece değerler ve dönüşümler.
#
# Bu dosyayı çalıştırmak için:
#   nix eval -f 01-values-and-types.nix
#   veya: nix repl → :l 01-values-and-types.nix
# ============================================================================

rec {
  # ── 1. SAYILAR (Integers) ───────────────────────────────────────────────
  # Nix'te sadece tam sayılar var. Float yok!
  sayi = 42;
  negatif = -7;
  toplama = 2 + 3;        # → 5
  carpma = 6 * 7;         # → 42
  bolme = 10 / 3;         # → 3 (integer bölme!)

  # ── 2. BOOLEAN ─────────────────────────────────────────────────────────
  dogru = true;
  yanlis = false;
  ve = true && false;     # → false
  veya = true || false;   # → true
  degil = !true;          # → false
  esit = 42 == 42;        # → true
  farkli = 42 != 43;     # → true

  # ── 3. STRINGS ─────────────────────────────────────────────────────────
  # Tek satırlık string
  isim = "zixar";

  # String interpolation — ${} ile değişken gömme
  selamlama = "Merhaba, ${isim}!";

  # Çok satırlık string (indented string) — '' ile
  # Otomatik olarak ortak indentation'ı kaldırır
  cokSatir = ''
    Bu bir
    çok satırlık
    string.
  '';

  # String birleştirme
  birlesik = "Nix" + "OS";  # → "NixOS"

  # ── 4. PATH (Dosya Yolu) ───────────────────────────────────────────────
  # Path'ler string'den farklı — Nix store'a kopyalanma davranışı var
  # Dikkat: Bu dosya evaluate edilirken path gerçekten resolve edilir
  ornekPath = ./README.md;          # Relative path
  # mutlakPath = /etc/nixos;        # Absolute path (uncomment to test)

  # ── 5. NULL ─────────────────────────────────────────────────────────────
  yok = null;
  nullKontrolu = if null == null then "evet, null" else "hayır";

  # ── 6. LİSTELER ────────────────────────────────────────────────────────
  # Listeler köşeli parantez ile, VIRGÜL YOK (boşluk ile ayrılır)
  basitListe = [ 1 2 3 4 5 ];
  karisikListe = [ "hello" 42 true null ];
  icIceListe = [ [ 1 2 ] [ 3 4 ] ];

  # builtins ile liste işlemleri
  listeUzunluk = builtins.length [ "a" "b" "c" ];  # → 3
  ilkEleman = builtins.head [ 10 20 30 ];           # → 10
  kalanlar = builtins.tail [ 10 20 30 ];            # → [ 20 30 ]
  birlestir = [ 1 2 ] ++ [ 3 4 ];                  # → [ 1 2 3 4 ]

  # ── 7. ATTRIBUTE SETS (Sözlük / Obje) ──────────────────────────────────
  # Nix'in en güçlü veri yapısı! JSON objelerine benzer.
  kisi = {
    ad = "zixar";
    yas = 25;
    diller = [ "Turkish" "English" ];
  };

  # Erişim: kisi.ad → "zixar"
  kisiAdi = kisi.ad;

  # ── 8. RECURSIVE ATTRIBUTE SETS ─────────────────────────────────────────
  # `rec` ile set içindeki değerler birbirini referans edebilir
  recOrnek = rec {
    x = 10;
    y = x * 2;    # → 20 (x'i kullanabilir çünkü rec)
    z = x + y;    # → 30
  };

  # ── 9. TİP KONTROLÜ ───────────────────────────────────────────────────
  # Nix dynamically typed — ama builtins ile kontrol edebilirsin
  tipKontrol = {
    intMi = builtins.isInt 42;          # → true
    stringMi = builtins.isString 42;    # → false
    listeMi = builtins.isList [ 1 2 ];  # → true
    setMi = builtins.isAttrs { a = 1; }; # → true
    nullMu = builtins.isNull null;      # → true
    tipAdi = builtins.typeOf "hello";   # → "string"
  };

  # ══════════════════════════════════════════════════════════════════════
  # 📝 PRATİK ÖDEV
  # ══════════════════════════════════════════════════════════════════════
  # 1. Kendi bilgilerinle bir `profil` attribute set oluştur
  # 2. İçine ad, soyad, yas, hobiler (liste) ekle
  # 3. String interpolation ile "Merhaba, ben <ad> <soyad>!" yaz
  # 4. `rec` kullanarak dogumYili = 2025 - yas hesapla
  #
  # Çözüm için bu attribute set'e kendi cevaplarını ekle:
  odev = {
    # Buraya yaz!
  };
}
