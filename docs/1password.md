# 1Password — kurulum notu ve doğrulama listesi

*Yazıldı: 2026-07-25 · Durum: **kod yazıldı + `nixos-rebuild build` geçti, HENÜZ `switch` YAPILMADI***

Kod: `modules/apps/onepassword.nix` (system katmanı), `configuration.nix`'ten import edilir.
Sürümler (pinli nixpkgs, 26.11): GUI **8.12.28**, CLI **2.34.1**.

## Neden system katmanı, neden bu üç parça

1Password Linux'ta root'un kurabileceği iki şeye bağlanıyor (polkit politikası + setgid
sarmalayıcılar), o yüzden HM'den (`home.nix`) kurulamaz.

| Parça | Ne yapar | Atlanırsa |
|---|---|---|
| `programs._1password-gui.polkitPolicyOwners = [ "zixar" ]` | nixpkgs modülü paketi bu değerle **override** eder; `com.1password.1Password.policy` içine `unix-user:zixar` gömülür (build çıktısında teyit edildi) | Uygulama açılır ama "sistem kimlik doğrulamasıyla kilidi aç" ve tarayıcı köprüsü izin hatası verir |
| `programs._1password.enable` | `op`'u setgid `onepassword-cli` sarmalayıcı olarak kurar | Düz `pkgs._1password-cli` binary'yi getirir ama CLI↔GUI eşleşmesi (CLI'yi masaüstünden yetkilendirme) çalışmaz — doğrulama grup kimliği üzerinden |
| `/etc/1password/custom_allowed_browsers` | Köprü, isteği gönderen sürecin `/proc/<pid>/exe` adını **sabit** izin listesiyle karşılaştırır; Zen listede yok | Zen eklentisi "masaüstü uygulamasına bağlanamadı" der |

Zen isim tespiti (bu makinede ölçüldü): çalışan sürecin exe'si
`…/lib/zen-bin-1.21.8b/zen` → **`zen`**; profildeki sarmalayıcılar `zen-beta` ve
`.zen-beta-wrapped`. Sürüme göre hangisinin görüldüğü oynayabildiği için üçü de yazılı.

## Switch sonrası doğrulama (kullanıcıda)

```bash
sudo nixos-rebuild switch --flake /home/zixar/nixos-zixar#nixos   # veya: nh os switch
```

- [ ] Uygulama açılıp giriş yapılıyor
- [ ] Ayarlar → **"Unlock using system authentication"** seçeneği görünüyor ve çalışıyor (polkit)
- [ ] Zen'e 1Password eklentisi kurulup "masaüstü uygulamasıyla bağlan" başarılı
  - bağlanmazsa: `readlink /proc/$(pgrep -n zen)/exe` → son parçayı
    `custom_allowed_browsers`'a ekle + rebuild
- [ ] `op --version` (2.34.1) ve `op signin` GUI ile eşleşiyor

## İdle güç uyarısı (4.28W bütçesi)

1Password kendiliğinden autostart **olmuyor** → kapalıyken arka planda hiçbir şey dönmez,
idle tabanı etkilenmez. Uygulama içinden "başlangıçta çalıştır" **açılırsa** oturum boyunca
bir daemon sürekli açık kalır — ölçmeden açma (`powertop`, BAT1 `current_now × voltage_now`).

## Açık devam maddeleri (yapılmadı)

- **1Password SSH agent** — ssh anahtarlarını kasada tutup git/ssh'ı ona yönlendirmek
  (`IdentityAgent ~/.1password/agent.sock`, HM tarafında `programs.ssh`).
- **`op` ile secret enjeksiyonu** — API anahtarlarını nix store'a sızdırmadan çekmek
  (`op run` / `op read`); `modules/apps/local-ai.nix` için aday.
- **İlgisiz ama bu iş sırasında görüldü:** `modules/apps/default.nix:52`'de
  `security.pam.services.gdm-password.enableGnomeKeyring = true` duruyor, ama display
  manager artık **ly** (2026-07-18 geçişi) → bu satır ölü, girişte gnome-keyring kilidi
  açılmıyor olabilir (Vesktop/Bitwarden token'larını etkiler). Doğru hedef muhtemelen
  `security.pam.services.ly.enableGnomeKeyring`. Ayrı iş olarak ele alınacak.
