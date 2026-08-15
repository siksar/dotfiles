# Hibrit çekirdek politikası — Zen5 ("büyük") / Zen5c ("verimlilik") ayrımı.
# Ölçüm ve gerekçe: Documentation/aerox16/cpu-hybrid.md (16 Ağu 2026).
#
# Bulgu: zamanlayıcı bu CPU'nun hibrit olduğunu BİLİYOR — ve hızlıyı tercih ediyor.
# amd_hfi sürücüsü AMDI0104:00'e bağlı, ITMT açık (sched_itmt_enabled = Y),
# sched_core_priority dolu (Zen5 196/203, Zen5c 135), workload classification aktif.
# Yani bir sekme/timer/repaint YAZI-TURA DEĞİL, sistematik olarak Zen5'e gidiyor;
# power-display.nix AC'de scaling_max_freq'i her seferinde 5.09GHz'e geri açtığı ve
# EPP balance_performance olduğu için kısa tek-thread'lik bir iş bile o çekirdeği
# tepeye çıkarıyor. Arıza değil — zamanlayıcı doğru çalışıyor, biz aynı fikirde değiliz.
#
# DİKKAT — ITMT arayüzü /proc/sys altında DEĞİL, debugfs'te (root gerekir):
#   sudo cat /sys/kernel/debug/x86/sched_itmt_enabled      → Y
#   sudo cat /sys/kernel/debug/x86/sched_core_priority     → per-CPU öncelik
#   sudo cat /sys/kernel/debug/x86/amd_hfi/class_capabilities
# 10 Ağu 2026'daki "zamanlayıcı kör" teşhisi, kaldırılmış /proc/sys/kernel/
# sched_itmt_enabled yoluna ve yanlış platform düğümüne (stub 'amd_hfi' cihazı,
# gerçek cihaz AMDI0104:00) bakmaktan doğan bir hataydı. Ayrıca prefcore=disabled
# bir eksiklik değil: HFI'li tasarımlarda upstream onu bilerek kapatıyor.
#
# Topoloji (Ryzen AI 7 350 "Krackan Point"):
#   Zen5  (büyük)      cpu 0,2,4,6   + SMT 8,10,12,14   → tavan 5090910 kHz (~5.09GHz)
#   Zen5c (verimlilik) cpu 1,3,5,7   + SMT 9,11,13,15   → tavan 3506494 kHz (~3.51GHz)
#
# Çözüm: kernel'in kararı GEÇERLİ ama idle güç bütçesiyle çelişiyor; manager'ı
# ELLE Zen5c'ye sabitleyip o kararı eziyoruz.
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
# İleride gözden geçirme koşulu: ESKİ koşul ("kernel bir gün amd_hfi'yi bağlarsa")
# ZATEN gerçekleşti — bağlı, ITMT açık. Bu dosya artık geçici protez değil, kalıcı
# bir politika tercihi: hızlı çekirdek KULLANILMASIN, çünkü 4.28W idle tabanı
# 5GHz'lik kısa patlamaları kaldırmıyor. Ancak güç bütçesi değişirse gözden geçir,
# kernel sürümü değişirse değil. (ITMT'yi kapatmak alternatif DEĞİL: 0 yazmak
# yerleşimi keyfîleştirir, "Zen5c'yi tercih et" diye bir mod yok; üstelik debugfs
# olduğu için kalıcı da değil.)
{ ... }:

{
  systemd.settings.Manager.CPUAffinity = "1,3,5,7,9,11,13,15"; # yalnız Zen5c

  # nix-daemon MUAF: nixos-rebuild/nh derlemeleri tüm 16 CPU'yu kullanmalı —
  # bu masaüstü politikasını delmiyor, derleme işi oturumdan bağımsız
  # system.slice'ta koşuyor zaten.
  systemd.services.nix-daemon.serviceConfig.CPUAffinity = "0-15";
}
