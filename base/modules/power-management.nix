{ config, pkgs, lib, ... }:
{
	# ========================================================================
	# LAPTOP POWER MANAGEMENT & UNDERVOLT TOOLS
	# Gigabyte Aero X16 1VH (AMD Ryzen + NVIDIA) için optimize edilmiş
	# ========================================================================

	environment.systemPackages = with pkgs; [
		# ─────────────────────────────────────────────────────────────────────
		# AMD RYZEN SPECIFIC TOOLS
		# ─────────────────────────────────────────────────────────────────────
    
		# System76 Power - Alternative power management
		system76-power
    
		# ─────────────────────────────────────────────────────────────────────
		# GENERAL POWER MANAGEMENT
		# ─────────────────────────────────────────────────────────────────────
    
		# PowerTop - Intel/AMD power consumption analyzer
		powertop
    
		# auto-cpufreq - Automatic CPU power management for laptops
		# auto-cpufreq (Disabled in favor of PPD)
    
		# s-tui - Terminal UI for monitoring CPU temp, freq, power
		s-tui
    
		# stress-ng - CPU stress testing (s-tui ile birlikte kullanılır)
		stress-ng
    
		# cpupower - CPU frequency scaling utilities
		config.boot.kernelPackages.cpupower
    
		# ─────────────────────────────────────────────────────────────────────
		# GPU & DISPLAY CONTROL
		# ─────────────────────────────────────────────────────────────────────
    
		# EnvyControl not in nixpkgs - install via pip if needed: pip install envycontrol
		# Alternative: use nvidia-offload wrapper or prime-run
    
		# glxinfo/glxgears - OpenGL testing (part of mesa-demos)
		mesa-demos
    
		# nvtop full - GPU monitoring (RTX 5060 support)
		nvtopPackages.full
    
		# Nvidia GPU Tools
		gwe # GreenWithEnvy - NOTE: X11 only, Wayland'da çalışmaz
    
		# LACT - Linux AMDGPU Controller (Wayland destekli, AMD+NVIDIA)
		lact
    
		# ─────────────────────────────────────────────────────────────────────
		# FAN & PERIPHERAL CONTROL
		# ─────────────────────────────────────────────────────────────────────
    
		# NBFC-Linux - Notebook Fan Control (Gigabyte profiles)
		nbfc-linux
    
		# OpenRGB - Keyboard and system RGB lighting control
		openrgb
    
		# ─────────────────────────────────────────────────────────────────────
		# THERMAL MANAGEMENT
		# ─────────────────────────────────────────────────────────────────────
    
		# lm_sensors - Hardware monitoring (fan speed, temps, voltages)
		lm_sensors
    
		# acpi - Battery and thermal info
		acpi
    
		# thermald - Thermal daemon (Intel/AMD thermal management)
		thermald
    
		# ─────────────────────────────────────────────────────────────────────
		# LAPTOP SPECIFIC
		# ─────────────────────────────────────────────────────────────────────
    
		# brightnessctl - Display brightness control
		brightnessctl
    
		# light - Alternative brightness controller
		light
    
		# acpilight - xbacklight replacement using ACPI
		acpilight
    
		# ─────────────────────────────────────────────────────────────────────
		# SYSTEM MONITORING & HARDWARE UTILS
		# ─────────────────────────────────────────────────────────────────────
    
		# btop - Modern resource monitor
		btop
    
		# iotop - I/O monitoring
		iotop
    
		# perf - Linux performance tools
		perf
    
		# pciutils - lspci command for hardware inspection
		pciutils
    
		# usbutils - lsusb command for USB device inspection
		usbutils
    
		# ─────────────────────────────────────────────────────────────────────
		# BIOS/FIRMWARE TOOLS
		# ─────────────────────────────────────────────────────────────────────
    
		# fwupd - Firmware updates via Linux (LVFS)
		fwupd
    
		# efibootmgr - EFI boot manager
		efibootmgr
    
		(pkgs.writeShellScriptBin "power-control" ''
			#!/usr/bin/env bash

			# ========================================================================
			# POWER CONTROL SCRIPT - KRAKEN POINT EDITION
			# ========================================================================
			# TARGET HARDWARE:
			#   CPU: AMD Ryzen AI 7 350 (Kraken Point: Zen 5 + Zen 5c)
			#   GPU: NVIDIA RTX 5060 Max-Q
			#   POWER: 100W PD (Power Delivery) Limited
			#
			# STRATEGY:
			#   1. CPU (amd-pstate): Use EPP via sysfs. Ideally 'balance_performance' 
			#      for 100W budget to leave headroom for GPU.
			#   2. GPU (nvidia): Use `nvidia-smi -lgc` (Lock Graphics Clock) instead of 
			#      power limits (-pl) where possible, as it's more stable on mobile.
			#      Limits are tuned to stay under 100W total system draw.
			#   3. Platform (amd-pmf): Set platform_profile if available.
			#
			# ------------------------------------------------------------------------

			check_root() {
				if [ "$EUID" -ne 0 ]; then
					echo "Please run as root"
					exit 1
				fi
			}

			# --- HELPERS ---

			set_platform_profile() {
				# AMD PMF / ACPI Platform Profile
				# performance, balanced, low-power
				PROFILE=$1
				if [ -f /sys/firmware/acpi/platform_profile ]; then
					echo "$PROFILE" > /sys/firmware/acpi/platform_profile 2>/dev/null || true
					echo "  • Platform Profile: ''${PROFILE}"
				fi
			}

			set_cpu_epp() {
				# AMD P-State EPP (Energy Performance Preference)
				# performance, balance_performance, balance_power, power
				EPP=$1
				if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
					echo "$EPP" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
					echo "  • CPU EPP: ''${EPP}"
				fi
			}

			set_cpu_gov() {
				# CPU Governor (amd-pstate usually defaults to powersave, but performance is valid too)
				GOV=$1
				cpupower frequency-set -g "$GOV" >/dev/null 2>&1 || true
				echo "  • CPU Governor: ''${GOV}"
			}

			set_gpu_clocks() {
				# NVIDIA Lock Graphics Clock (LGC) - X11 Independent!
				# Usage: set_gpu_clocks <MinMHz> <MaxMHz>
				MIN=$1
				MAX=$2
				
				# Reset clocks first
				if [ "$MIN" == "0" ]; then
					nvidia-smi -rgc >/dev/null 2>&1
					echo "  • GPU Clocks: Reset to Auto"
				else
					nvidia-smi -lgc "$MIN,$MAX" >/dev/null 2>&1
					if [ $? -eq 0 ]; then
						echo "  • GPU Clocks: Locked to ''${MAX} MHz"
					else
						echo "  ⚠ GPU Lock Failed (Not Supported?)"
					fi
				fi
			}

			set_gpu_power() {
				# NVIDIA Power Limit (PL) in Watts
				# Note: Max-Q often ignores this or has a narrow range (e.g. 35W-115W)
				WATTS=$1
				nvidia-smi -pl "$WATTS" >/dev/null 2>&1
				if [ $? -eq 0 ]; then
					echo "  • GPU Power Target: ''${WATTS}W"
				else
					echo "  ⚠ GPU Power Set Failed (Firmware Locked?)"
				fi
			}

			# --- PROFILES ---

			apply_pd_gaming() {
				echo ">>> Applying PD-GAMING Profile (100W PD Optimized)"
				echo "    Target: CPU ~25W | GPU ~45W | Sys ~20W"
				
				# 1. Platform: Balanced (Don't let CPU eat all power)
				set_platform_profile "balanced"
				
				# 2. CPU: Efficient Gaming (Zen 5c effective)
				set_cpu_epp "balance_performance"
				set_cpu_gov "powersave" # Let P-State handle freq via EPP
				
				# 3. GPU: Sweet Spot Efficiency
				# RTX 5060 mobile sweet spot is often 1950-2100 MHz @ ~45-50W
				set_gpu_clocks 1900 2100
				set_gpu_power 50
			}

			apply_pd_balanced() {
				echo ">>> Applying PD-BALANCED Profile (Daily Use)"
				echo "    Target: Quiet & Efficient"
				
				set_platform_profile "balanced"
				set_cpu_epp "balance_power"
				set_cpu_gov "powersave"
				
				# GPU: Low clock cap for UI/Video/Light Gaming
				set_gpu_clocks 1200 1500
				set_gpu_power 35
			}

			apply_ac_gaming() {
				echo ">>> Applying AC-GAMING Profile (Max Performance)"
				echo "    Target: Unleash everything (Battery ignored)"
				
				set_platform_profile "performance"
				set_cpu_epp "performance"
				set_cpu_gov "performance"
				
				# GPU: Max Boost
				set_gpu_clocks 2200 2550
				set_gpu_power 80 # Or Max TGP
			}

			apply_saver() {
				echo ">>> Applying SAVER Profile (Battery Life)"
				
				set_platform_profile "low-power"
				set_cpu_epp "power"
				set_cpu_gov "powersave"
				
				# GPU: Minimize
				set_gpu_clocks 210 1200
				set_gpu_power 25
			}

			apply_default() {
				echo ">>> Reseting to Default"
				nvidia-smi -rgc >/dev/null 2>&1
				nvidia-smi -pm 0 >/dev/null 2>&1 # Disable persistence optional
				set_platform_profile "balanced"
				set_cpu_epp "balance_performance"
			}

			# --- MAIN ---

			check_root
			MODE=$1

			case "$MODE" in
				"pd-gaming") apply_pd_gaming ;;
				"pd-balanced") apply_pd_balanced ;;
				"gaming"|"ac-gaming"|"turbo") apply_ac_gaming ;;
				"saver"|"eco") apply_saver ;;
				"default"|"normal") apply_default ;;
				"auto")
					# Simple logic based on power source
					STATUS=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 1)
					if [ "$STATUS" == "1" ]; then
						apply_ac_gaming
					else
						apply_pd_balanced
					fi
					;;
				*)
					echo "Usage: power-control {pd-gaming|pd-balanced|ac-gaming|saver|default}"
					echo "  pd-gaming   : Optimized for 100W USB-C PD (CPU+GPU balanced)"
					echo "  pd-balanced : Daily use on PD"
					echo "  ac-gaming   : Full power on barrel plug"
					echo "  saver       : Max battery life"
					exit 1
					;;
			esac
		'')
    
		# Ultra düşük güç modu - idle için
		(pkgs.writeShellScriptBin "idle-optimize" ''
			#!/usr/bin/env bash
			# Idle Power Optimization Script
			# Ultra düşük güç tüketimi ve sıcaklık için
      
			check_root() {
					if [ "$EUID" -ne 0 ]; then
							echo "Please run as root: sudo idle-optimize"
							exit 1
					fi
			}
      
			apply_idle() {
					echo "Applying IDLE optimization mode..."
					
					# PMF: Power Saver Mode
					if command -v powerprofilesctl &> /dev/null; then
							powerprofilesctl set power-saver || true
					fi
          
					# Frekans sınırla
					cpupower frequency-set --max 2000MHz 2>/dev/null || echo "cpupower not available"
          
					# EPP ayarla
					if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
							echo "power" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
					fi
          
					# Platform profile (Direct ACPI Fallback)
					if [ -f /sys/firmware/acpi/platform_profile ]; then
							echo "low-power" > /sys/firmware/acpi/platform_profile || true
					fi
          
					echo "✓ Idle optimization applied (PMF Power-Saver)"
			}
      
			restore_normal() {
					echo "Restoring NORMAL mode..."
					
					if command -v powerprofilesctl &> /dev/null; then
							powerprofilesctl set balanced || true
					fi

					cpupower frequency-set --max 5100MHz 2>/dev/null || echo "cpupower not available"
          
					if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
							echo "balance_performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
					fi
          
					if [ -f /sys/firmware/acpi/platform_profile ]; then
							echo "balanced" > /sys/firmware/acpi/platform_profile || true
					fi
          
					echo "✓ Normal mode restored (PMF Balanced)"
			}
      
			check_root
			case "$1" in
					"on"|"idle") apply_idle ;;
					"off"|"normal") restore_normal ;;
					*)
							echo "Usage: sudo idle-optimize {on|off}"
							echo "  on/idle  - Ultra low power mode (6W/PMF Saver)"
							echo "  off/normal - Restore normal operation"
							;;
			esac
		'')
	];

	# ========================================================================
	# NOTE: thermald.enable is also in cpu-scheduling.nix, using mkDefault to allow override
	services.thermald.enable = lib.mkDefault true;

	# ========================================================================
	# POWER PROFILES DAEMON
	# ========================================================================
	# ========================================================================
	# POWER PROFILES DAEMON
	# ========================================================================
	services.power-profiles-daemon.enable = true;
	
	# ========================================================================
	# UPOWER - Battery Reporting
	# ========================================================================
	services.upower.enable = true;

	# Explicitly disable conflicting services
	services.tlp.enable = false;
	services.auto-cpufreq.enable = false;
	# Accelerometer vb. sensörler

	# ========================================================================
	# UDEV RULES - RyzenAdj ve diğer araçlar için gerekli izinler
	# ========================================================================
	# ========================================================================
	# CUSTOM POWER CONTROL SCRIPT
	# ========================================================================

	# ========================================================================
	# UDEV RULES - Auto Power Switching
	# ========================================================================
	services.udev.extraRules = ''
		# RyzenAdj ...
		KERNEL=="msr", MODE="0660", GROUP="wheel"
		SUBSYSTEM=="cpu", MODE="0660", GROUP="wheel"

		# Auto Power Control on AC/Battery Switch
		SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.bash}/bin/bash /run/current-system/sw/bin/power-control saver"
		SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.bash}/bin/bash /run/current-system/sw/bin/power-control normal"
    
		# Backlight ...
		ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
		ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    
		# NVIDIA GPU ...
		ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
		ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
	'';

	# ========================================================================
	# SUDO RULES FOR POWER CONTROL
	# ========================================================================
	security.sudo.extraRules = [
		{
			groups = [ "wheel" ];
			commands = [
				{ command = "/run/current-system/sw/bin/power-control"; options = [ "NOPASSWD" ]; }
				{ command = "${config.boot.kernelPackages.cpupower}/bin/cpupower"; options = [ "NOPASSWD" ]; }
				# Note: nvidia-smi might need to be explicitly added if not covered
			];
		}
	];

	# ========================================================================
	# LACT DAEMON SERVICE
	# ========================================================================
	systemd.services.lactd = {
		description = "AMDGPU Control Daemon";
		after = ["multi-user.target"];
		wantedBy = ["multi-user.target"];
		serviceConfig = {
			ExecStart = "${pkgs.lact}/bin/lact daemon";
			Nice = -10;
			Restart = "on-failure";
		};
		enable = true;
	};

	# ========================================================================
	# NOTEBOOK FAN CONTROL (NBFC) 
	# ========================================================================
	# Laptop fanları genellikle GPU driver üzerinden değil EC üzerinden kontrol edilir
	# LACT çalışmıyorsa NBFC kullanın
  
 # systemd.services.nbfc_service = {
	#  description = "Notebook Fan Control Service (nbfc-linux)";
	#  enable = true;
	#  wantedBy = [ "multi-user.target" ];
	#  serviceConfig = {
	#    ExecStart = "${pkgs.nbfc-linux}/bin/nbfc_service";
	#    Restart = "always";
	#  };
	#};
}
