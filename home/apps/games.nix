# Oyun (HM katmanı): gamerun sarmalayıcısı — tanımı lib/gamerun.nix'te (10 Ağu
# 2026'da taşındı; gerekçe orada). Burası yalnız normal PATH'e ekliyor —
# mc-run (home/apps/minecraft.nix) ve emu-run (home/apps/emu.nix) buradan çeker.
# Steam tarafı usr/steam.nix → programs.steam.extraPackages (FHS kum havuzu).
# NOT (2026-07-22): MangoHud + gamescope KALDIRILDI. Gerekçe: MangoHud oyun↔Vulkan
# sürücüsü arasına giren bir katman (burada segfault geçmişi var) → kaldırmak DXVK/VKD3D
# iletişimini sadeleştirir; gamescope bu hibritte (AMD iGPU + NVIDIA offload) çöküyordu.
# Oyun-içi ölçüm artık dış araçla: ikinci terminalde `nvtop` / `nvidia-smi dmon`.
{ pkgs, ... }:

{
  home.packages = [ (import ../../lib/gamerun.nix { inherit pkgs; }) ];
}
