# adi1090x/rofi tema portu — waybar'ın mono paletiyle boyanır.
#
# Waybar'ın 15 vendor temasıyla aynı mantık (bkz. waybar-themes.nix): üst kaynak
# dosyası OLDUĞU GİBİ vendor'lanır, bizim her sapmamız ayrı bir "override"
# katmanında durur ve build-time'da dosyanın SONUNA eklenir (rasi'de de CSS'te
# olduğu gibi son kural kazanır — sıra ters çevrilirse üst kaynağın renkleri
# geri gelir).
#
# Renklerin TEK kaynağı waybar-mono.css'tir: oradaki bir hex'i değiştirmek 15
# waybar temasını VE bu rofi temasını birlikte döndürür.
{ pkgs, lib }:

let
  # "@define-color ad #hex;" satırlarını attrset'e çevirir.
  # Neden CSS dosyasını ayrıştırıyoruz da paleti Nix'e kopyalamıyoruz: iki
  # kopya kaçınılmaz olarak birbirinden ayrışır; waybar tarafı zaten bu CSS'i
  # okumak ZORUNDA (@import ile), o yüzden tek yön bu.
  palette =
    let
      lines = lib.splitString "\n" (builtins.readFile ../bar/waybar-mono.css);
      hits = lib.filter (m: m != null) (
        map (l: builtins.match " *@define-color +([a-zA-Z0-9_-]+) +(#[0-9a-fA-F]+) *; *" l) lines
      );
    in
    builtins.listToAttrs (
      map (m: lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1)) hits
    );

  # @@ad@@ yer tutucuları → palet hex'leri.
  # Neden yer tutucu da rasi'nin kendi @değişken'i DEĞİL: rofi 2.0
  # `linear-gradient(...)` İÇİNDE @değişken'i ayrıştıramıyor ve tek bir böyle
  # satır yüzünden tema dosyasının TAMAMINI sessizce reddedip dahili Solarized
  # light temasına düşüyor (ölçüldü: `rofi -theme … -dump-theme` → "Failed to
  # parse theme", çıkışta #fdf6e3). Seçim durakları gradient olduğu için tüm
  # renkleri build-time'da literal hex'e çevirmek tek güvenli yol.
  substitutions = lib.concatLists (
    lib.mapAttrsToList (n: v: [
      "--replace-quiet"
      "@@${n}@@"
      v
    ]) palette
  );

  style4 = pkgs.runCommand "rofi-type-5-style-4.rasi" { } ''
    cat ${./rofi-themes/type-5/style-4.rasi} > theme.rasi
    printf '\n' >> theme.rasi
    cat ${./rofi-mono-overrides.rasi} >> theme.rasi
    substituteInPlace theme.rasi ${lib.escapeShellArgs substitutions}
    cp theme.rasi $out
  '';

  # matugen'in ürettiği ~/.config/rofi/colors.rasi'nin mono ikizi: AYNI değişken
  # adlarını kullanır, böylece onu import eden dosyalarda (wallpaper-grid.rasi)
  # dinamik renklere dönmek tek satırlık bir import değişikliği kalır.
  # Burada @değişken güvenli — gradient kullanan tek dosya style-4.
  monoColors = pkgs.writeText "rofi-mono-colors.rasi" ''
    /* ÜRETİLMİŞ DOSYA — elle düzenleme.
     * Kaynak: home/desktop/bar/waybar-mono.css */
    * {
        bg:        ${palette.background};
        bg-alt:    ${palette.surface};
        fg:        ${palette.foreground};
        fg-dim:    ${palette.muted};
        accent:    ${palette.bright};
        on-accent: ${palette.background};
        urgent:    ${palette.bright};
    }
  '';
in
{
  inherit palette style4 monoColors;
}
