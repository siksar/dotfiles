# Hibrit çekirdek politikası — Zen5 ("büyük") / Zen5c ("verimlilik") ayrımı.
# Ölçüm ve gerekçe: Documentation/aerox16/cpu-hybrid.md (10 Ağu 2026).
#
# Bulgu: bu çekirdek zamanlayıcı bu CPU'nun hibrit olduğunu BİLMİYOR.
# amd_pstate/prefcore=disabled, her CPU'da amd_pstate_hw_prefcore=disabled,
# /proc/sys/kernel/sched_itmt_enabled hiç oluşmamış, cpu_capacity 16 CPU'da da
# 1024 (hepsi eşit sanılıyor). amd_hfi platform cihazı VAR ama driver symlink'i
# yok → sürücü bağlanmamış. Firmware sıralamayı veriyor (ACPI'de "AMD Hetero"
# SSDT'si, amd_pstate_prefcore_ranking Zen5'te 196-208 / Zen5c'de 135) ama hiçbiri
# EEVDF'ye ulaşmıyor. Sonuç: bir sekme/timer/repaint yazı-tura ihtimalle bir Zen5
# çekirdeğine düşüyor, power-display.nix AC'de scaling_max_freq'i her seferinde
# 5.09GHz'e geri açtığı ve EPP balance_performance olduğu için kısa tek-thread'lik
# bir iş bile o çekirdeği tepeye çıkarmaya yetiyor. Arıza değil — zamanlayıcı kör.
#
# Topoloji (Ryzen AI 7 350 "Krackan Point"):
#   Zen5  (büyük)      cpu 0,2,4,6   + SMT 8,10,12,14   → tavan 5090910 kHz (~5.09GHz)
#   Zen5c (verimlilik) cpu 1,3,5,7   + SMT 9,11,13,15   → tavan 3506494 kHz (~3.51GHz)
#
# Çözüm: kernel kendi karar veremediği için manager'ı ELLE Zen5c'ye sabitliyoruz.
# systemd PID1'in CPUAffinity'si tüm alt süreçlere MİRAS kalır (fork/exec zinciri
# boyunca aksi belirtilmedikçe) → masaüstü/tarayıcı/compositor dahil her şey
# fiziksel olarak Zen5c'de kalır, 5GHz o çekirdeklerde yapısal olarak imkânsız
# hale gelir (tavanları 3506494 kHz). Zen5'ler talep gelmeyince C-state'e düşer.
#
# YUMUŞAK maske: bu sched_setaffinity (systemd manager düzeyinde), cgroup
# AllowedCPUs DEĞİL — o yüzden taskset ile her zaman geri açılabilir (gamerun,
# aşağıdaki `aia` alias'ı). AllowedCPUs bilinçli seçilmedi: cgroup düzeyinde
# kısıtlama çocuk süreçlerin taskset ile bile kaçmasını engeller, gamerun'ın
# oyunu 16 CPU'ya açması imkânsız olurdu.
#
# Kapatmak için: CPUAffinity satırını yorum satırı yap + rebuild.
#
# İleride gözden geçirme koşulu: kernel bir gün amd_hfi'yi bu cihazda gerçekten
# bağlarsa (driver symlink'i oluşursa) ve/veya prefcore aktifleşirse, zamanlayıcı
# kendi kararını verebilir hale gelir — bu dosya o zaman gereksiz hale gelebilir.
{ ... }:

{
  systemd.settings.Manager.CPUAffinity = "1,3,5,7,9,11,13,15"; # yalnız Zen5c

  # nix-daemon MUAF: nixos-rebuild/nh derlemeleri tüm 16 CPU'yu kullanmalı —
  # bu masaüstü politikasını delmiyor, derleme işi oturumdan bağımsız
  # system.slice'ta koşuyor zaten.
  systemd.services.nix-daemon.serviceConfig.CPUAffinity = "0-15";
}
