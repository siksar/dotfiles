# PS3/PS4 emülatörleri (HM katmanı): RPCS3 + shadPS4 + emu-run sarmalayıcısı
# Offload + gamemode + game-perf zinciri Steam/Minecraft ile AYNI gamerun'a bağlanır:
# emu-run bir emülatörü gamerun'a delegate eder; gamerun dGPU PRIME env'lerini set
# eder ve (AC'de) game-perf.service (scx_lavd + 0xED perf profili) zincirini tetikler.
# DLSS/Reflex/ntsync env'leri native (Proton'suz) Vulkan emülatörlerinde no-op → zararsız.
# Ayrıntı: Documentation/gaming.md "PS3/PS4 Emülatörleri" bölümü.
#
# Sürüm takibi (elle — bu repoyu izleyen commit'le güncellenir):
#   • rpcs3: nixpkgs pinli (şu an 0.0.40-unstable-2026-04-25)
#   • shadps4: nixpkgs pinli (0.16.0; upstream son 0.17.0, 30 Tem 2026)
#     — 0.16.0 Bloodborne-uyumlu 0.15+ eşiğini geçtiği için override YAZILMADI.
#       Override gerekirse: github:shadps4-emu/shadPS4/<tag> flake input + src override.
#       Bedel: 191MB src + kaynaktan CMake derleme + nixpkgs bump'ta rebase riski.
{ pkgs, ... }:

let
  # emu-run — PRIME offload + gamemode zincirine emülatör delegesi.
  # Kullanım:
  #   emu-run rpcs3 [...]      (RPCS3 native Vulkan, Wayland/X11)
  #   emu-run shadps4 [...]    (shadPS4 native Vulkan + SDL3)
  #
  # Neden gamerun'a bağladık:
  #  (1) PRIME env'leri (__NV_PRIME_RENDER_OFFLOAD, __VK_LAYER_NV_optimus=NVIDIA_only)
  #      gamerun'da doğru ve tutarlı ayarlanıyor — evdev/hidapi bağlamı da oradan geliyor.
  #  (2) `gamemoderun` sarmalaması otomatik gelir → game-perf.service (scx_lavd + AC'de
  #      0xED perf profili) tetiklenir, CPU pinleme (GR_PIN=big) opsiyonu kullanılabilir.
  #  (3) Native Vulkan emülatörleri Proton'a ihtiyaç duymaz; DLSS/Reflex env'leri zararsız
  #      no-op'tur (yalnız Proton çeviri katmanında yorumlanırlar).
  #
  # Controller (DualSense/DualShock4/XInput):
  #  • hidapi + libevdev her iki emülatör derivation'ında zaten var (nix eval ile doğrulandı).
  #  • RPCS3: Ayarlarda "Handlers → SDL" seçilir; DualSense'i SDL3 tanır (evdev fallback).
  #  • shadPS4: SDL3 pad desteği yerleşik (derivation buildInputs'ta sdl3 + libxi).
  #  • dualsensectl (system tarafında, configuration.nix): LED/şarj okuma, USB pairing.
  #    Yeni daemon DEĞİL — CLI on-demand; idle'da 0 W katkısı (4.28W bütçesine dokunmaz).
  emu-run = pkgs.writeShellScriptBin "emu-run" ''
    # emu-run — dGPU PRIME offload + gamemode zincirine emülatör delegesi
    # Kullanım: emu-run {rpcs3|shadps4} [argümanlar...]
    # PRIME env + gamemode gamerun'dan miras (exec eder). Proton env'leri native
    # Vulkan emülatörlerinde no-op → RPCS3/shadps4'de zararsız.
    case "$1" in
      rpcs3)   shift; exec gamerun ${pkgs.rpcs3}/bin/rpcs3 "$@" ;;
      shadps4) shift; exec gamerun ${pkgs.shadps4}/bin/shadps4 "$@" ;;
      *)
        echo "emu-run: bilinmeyen emülatör: $1" >&2
        echo "Kullanım: emu-run {rpcs3|shadps4} [argümanlar...]" >&2
        exit 2
        ;;
    esac
  '';
in
{
  # Paketler: emülatörler + sarmalayıcı. dualsensectl system tarafında
  # (configuration.nix environment.systemPackages) — tek kurulum, kullanıcı-başısı değil.
  home.packages = [
    pkgs.rpcs3
    pkgs.shadps4
    emu-run
  ];

  # KULLANIM UYARISI: bu rice'da rofi .desktop başlatma PRIME env'lerini set ETMEZ.
  # rpcs3/shadps4 paketleri kendi .desktop'larını kurar (iGPU'ya düşer). dGPU'ya
  # yönlendirmenin tek güvenli yolu terminalden `emu-run rpcs3` / `emu-run shadps4`.
  # İleride .desktop override edip PRIME env'leri baked-in yapılabilir
  # (home/desktop/launcher altında); şu an gerekmedi — kullanıcı terminali tercih ediyor.
}
