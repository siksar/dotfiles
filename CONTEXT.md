# NixOS Optimization Agent - Context Document

## 1. Hardware Profile
| Component | Details |
|---|---|
| **Laptop** | Gigabyte AERO X16 (EG61H) |
| **CPU** | AMD Ryzen AI 7 350 (Krackan Point, Zen 5, 8C/16T) |
| **iGPU** | AMD Radeon 860M (gfx1152, RDNA3.5, PCI Address `65:00.0`, bus ID 101) |
| **dGPU** | NVIDIA GeForce RTX 5060 Max-Q (Blackwell, PCI Address `64:00.0`, bus ID 100) |
| **RAM** | 32 GB DDR5 5600 MT/s (2x 16 GB Micron CT16G56C46S5.M8D1) |
| **Storage** | 1x Kingston OM8PGP4 NVMe PCIe SSD (953.9 GB) |
| **WiFi** | Realtek RTL8852CE PCIe 802.11ax Wireless Network Controller |
| **Display** | eDP-1 2560x1600 @ 165Hz (VRR supported) |
| **BIOS Vendor/Version** | American Megatrends International, LLC. FB0A (05/28/2026) |

## 2. OS & Environment
- **OS**: NixOS 25.11 (Xantusia), channel 25.11.8478.bcd464ccd2a1
- **Current Kernel**: Linux 6.19.10
- **Compositor**: KDE Plasma 6 (Wayland session active)

## 3. PowerTOP Baseline Readings (2026-06-28)
### Measurement A (Antigravity active)
- **Discharge**: 5.63 W
- **Wakeups**: 1819.4 /s
- **CPU use**: 11.2 %
- **Top sources**: Antigravity sandboxes (~1031/s), tick_nohz_handler (308/s), rtw89 stack (~196/s)

### Measurement B (Idle)
- **Discharge**: 4.87 W
- **Wakeups**: 352.6 /s
- **CPU use**: 3.8 %
- **Top sources**:
  - `tick_nohz_handler`: 112.5 /s
  - `dm_handle_vmin_vmax_update`: 59.9 /s
  - `irq/132-rtw89_p`: 36.1 /s
  - `cfg80211_wiphy_work`: 32.3 /s
  - `sched(softirq)`: 18.2 /s
  - KDE compositor (`kded6`, `kwin`): ~20 /s
  - `NetworkManager`: 3.9 /s

## 4. Goals and Targets
- **Primary**: ~2.0 W idle discharge rate at battery
- **Secondary**:
  - Wakeups < 80/s at idle
  - Stable suspend/resume (s2idle)
  - Hardware video encode/decode via AMD VCN (VA-API)
  - Dynamic energy profiles (EPP) for AC/Battery
  - Panel Self Refresh (PSR) if stable on gfx1152
  - dGPU offloaded and completely powered down when inactive

## 5. Known Issues and Status
| Issue | Workaround | Status |
|---|---|---|
| gfx1152 MES hang on resume | `amdgpu.cwsr_enable=0` | Open. Verify under latest kernel. |
| NVIDIA open driver s2idle hang | `powerManagement` adjustments | Open. Needs test. |
| RDNA3.5 PSR/Panel Replay | DC module updates | Check stability on 6.19+. |
| rtw89_8852ce power save | clkreq/aspm disablers | Modprobe options to be tested. |
| AMD gpu voltage oscillation | `amdgpu.gfx_off=1` | Test effectiveness. |

## 6. Phase Completion Log
- **Phase 0 (Context Document)**: Completed (this file)
- **Phase 1 (Hardware Detection)**: Completed
- **Phase 2 (Flake Setup)**: Pending
- **Phase 3 (Home Manager Integration)**: Pending
- **Phase 4 (Kernel Selection)**: Pending
- **Phase 5 (NVIDIA Configuration)**: Pending
- **Phase 6 (amdgpu Power Configuration)**: Pending
- **Phase 7 (CPU Power Configuration)**: Pending
- **Phase 8 (WiFi Power Save)**: Completed (2026-07-20). Regdomain `00`→`TR` (cfg80211 modprobe, `iw`/`ethtool` eklendi); WiFi power_save AC/BAT-uyarlamalı (AC kapalı = en düşük gecikme/kararlı rtw89, BAT açık = 4.28W bütçesi) — mevcut `power-display` udev(ACAD)+boot oneshot deseni içine; ağ yığını `bbr`+`fq`+TFO; DNS systemd-resolved önbellek (Mullvad uyumlu, DoT yok); kablo takılınca WiFi oto-kapanır (NM dispatcher + boot oneshot arbiter, `eno1/carrier`). Bkz. `modules/networking.nix`, `modules/hardware/power-display.nix`.
- **Phase 9 (Hardware Video Decode)**: Pending
- **Phase 10 (Baseline Measurement)**: Pending
- **Phase 11 (Config Cleanup)**: Pending

## 7. Documentation Sources
- NixOS Wiki (NVIDIA, Flakes, Home Manager): https://wiki.nixos.org/
- amdgpu kernel parameters: https://www.kernel.org/doc/html/latest/gpu/amdgpu/
- AMD P-State driver: https://www.kernel.org/doc/html/latest/admin-guide/pm/amd-pstate.html
