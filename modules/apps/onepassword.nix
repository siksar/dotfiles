# 1Password — masaüstü uygulaması + `op` CLI (system katmanı)
#
# Neden system katmanı: 1Password Linux'ta kendini iki noktada çekirdeğe/PAM'e
# bağlar (polkit ile sistem-parolasıyla kilit açma, setgid'li tarayıcı köprüsü).
# İkisi de root'un kurabileceği şeyler → HM'den (home.nix) kurulamaz.
{ ... }:

{
  # GUI. NixOS modülü paketi `polkitPolicyOwners` ile override eder: bu listedeki
  # kullanıcılar için bir polkit politikası üretilir → uygulamadaki "sistem kimlik
  # doğrulamasıyla kilidi aç" (PAM/parola) seçeneği çalışır. Liste boş bırakılırsa
  # program yine açılır ama sistem-auth ve tarayıcı köprüsü izin hatası verir.
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "zixar" ];
  };

  # CLI. Modül `op`'u setgid `onepassword-cli` sarmalayıcı olarak kurar; masaüstü
  # uygulamasıyla eşleşme (CLI'yi GUI oturumundan yetkilendirme) bu grup kimliği
  # üzerinden doğrulanıyor — düz `pkgs._1password-cli`'yi systemPackages'a atmak
  # bu bağı kurmaz.
  programs._1password.enable = true;

  # ── Tarayıcı entegrasyonu (Zen) ──────────────────────────────────────────
  # 1Password-BrowserSupport, native-messaging isteğini gönderen sürecin
  # /proc/<pid>/exe adını SABİT bir izinli-tarayıcı listesiyle karşılaştırır;
  # Zen bu listede yok → eklenti "1Password masaüstü uygulamasına bağlanamadı"
  # der. Bu dosya listeyi genişletir (root'a ait, başkasına yazılabilir olmamalı).
  # Adlar: çalışan süreç `zen` (lib/zen-bin-*/zen), profildeki sarmalayıcılar
  # `zen-beta` / `.zen-beta-wrapped` — hangisinin görüldüğü sarmalayıcı sürümüne
  # göre değişebildiği için üçü birden yazılı, fazlası zararsız.
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      zen
      zen-beta
      .zen-beta-wrapped
    '';
    mode = "0755";
  };
}
