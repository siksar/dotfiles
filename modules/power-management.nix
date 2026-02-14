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
		linuxPackages_latest.cpupower
    
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
		linuxPackages_latest.perf
    
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

			# Power Control Script - AMD-PMF Edition
			# Optimized for: Gigabyte Aero X16 (Ryzen AI 7 350 + RTX 5060)
			# Strategy: Trust AMD-PMF for Platform (CPU/Fan) but force NVIDIA for GPU.
      
			# Display & Authority setup for nvidia-settings
			export DISPLAY=:0
			
			# Robust XAUTHORITY detection for Wayland/GDM/SDDM
			# We need to find the Xauthority file owned by the user to allow root to talk to X/Xwayland
			detect_xauth() {
				local USER_UID=$(id -u zixar)
				# 1. Standard home location
				if [ -f "/home/zixar/.Xauthority" ]; then
					echo "/home/zixar/.Xauthority"
					return
				fi
				
				# 2. Search in /run/user/UID (GDM, Wayland often puts it here)
				# Look for files starting with .mutter, .Xauth, or just xauth
				for candidate in $(find /run/user/$USER_UID -maxdepth 2 -name "*auth*" 2>/dev/null); do
					if [ -f "$candidate" ]; then
						echo "$candidate"
						return
					fi
				done
			}

			XAUTH_FILE=$(detect_xauth)
			if [ -n "$XAUTH_FILE" ]; then
				export XAUTHORITY="$XAUTH_FILE"
			else
				echo "⚠ Warning: Could not find XAUTHORITY file. Nvidia settings might fail."
			fi

			check_root() {
					if [ "$EUID" -ne 0 ]; then
							echo "Please run as root"
							exit 1
					fi
			}

			# Check if AMD PMF is active
			check_pmf() {
				if [ -d "/sys/devices/platform/amd-pmf" ]; then
					echo "✔ AMD PMF Driver Loaded"
				else
					echo "⚠ AMD PMF Not Detected (Check Kernel)"
				fi
			}

			set_profile() {
					echo "Setting Platform Profile: $1..."
					# This talks to amd-pmf driver via ACPI tables
					if command -v powerprofilesctl &> /dev/null; then
							powerprofilesctl set "$1" || true
					elif [ -f /sys/firmware/acpi/platform_profile ]; then
							echo "$1" > /sys/firmware/acpi/platform_profile || true
					fi
			}

			set_epp() {
					# AMD P-State EPP Control (Works with PMF)
					if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
							echo "Setting EPP: $1"
							echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
					fi
			}

			set_governor() {
				# Smart governor selection
				DESIRED=$1
				# If schedutil requested but not available, fallback to powersave (amd-pstate default)
				if [ "$DESIRED" = "schedutil" ]; then
					if ! grep -q "schedutil" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
						DESIRED="powersave"
					fi
				fi
				echo "Setting CPU Governor: $DESIRED"
				cpupower frequency-set -g "$DESIRED" >/dev/null 2>&1 || true
			}

			apply_gpu_clocks() {
					CORE=$1
					MEM=$2
					echo "Applying GPU Clocks: Core +$CORE MHz, Mem +$MEM MHz..."
					if command -v nvidia-settings &> /dev/null; then
						 # Requires X server access
						 echo "Debug: Using XAUTHORITY=$XAUTHORITY DISPLAY=$DISPLAY"
						 nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=$CORE" \
														 -a "[gpu:0]/GPUMemoryTransferRateOffset[3]=$MEM"
						 if [ $? -ne 0 ]; then
							 echo "⚠ Failed to apply GPU clocks (Check DISPLAY/XAUTHORITY or Wayland compatibility)"
						 else
							 echo "✔ GPU clocks applied"
						 fi
					fi
			}

			apply_gpu_power() {
				LIMIT=$1
				echo "Setting GPU Power Limit: $LIMIT W"
				nvidia-smi -pl "$LIMIT" >/dev/null 2>&1
				if [ $? -ne 0 ]; then
					echo "⚠ Could not set power limit (Locked by firmware?)"
				fi
			}

			# POWER MODES (AMD-PMF + NVIDIA Manual)

			apply_gaming() {
					echo "Applying GAMING mode (PMF Performance + 50W GPU)..."
					check_pmf
					
					# 1. Platform: "Performance"
					set_profile "performance"
					set_epp "performance"
          
					# 2. GPU: 50W Limit (Manual Override)
					apply_gpu_power 50
					apply_gpu_clocks 150 400
					
					# 3. CPU Governor
					set_governor "schedutil"
			}

			apply_turbo() {
					echo "Applying TURBO mode (PMF Performance + 60W GPU)..."
					check_pmf
					set_profile "performance"
					set_epp "performance"
					apply_gpu_power 60
					apply_gpu_clocks 180 600
					set_governor "performance"
			}

			apply_extreme() {
					echo "Applying EXTREME mode (Max Limits)..."
					check_pmf
					set_profile "performance"
					set_epp "performance"
					apply_gpu_power 80
					apply_gpu_clocks 200 1000
					set_governor "performance"
			}

			apply_normal() {
					echo "Applying NORMAL mode (PMF Balanced)..."
					check_pmf
					set_profile "balanced"
					set_epp "balance_performance"
					apply_gpu_power 30
					apply_gpu_clocks 0 0
					set_governor "schedutil"
			}

			apply_saver() {
					echo "Applying SAVER mode (PMF Power-Saver)..."
					check_pmf
					set_profile "power-saver"
					set_epp "power"
					apply_gpu_power 25
					apply_gpu_clocks 0 0
					set_governor "powersave"
			}

			check_root
			MODE=$1
			case "$MODE" in
					"gaming") apply_gaming ;;
					"turbo") apply_turbo ;;
					"extreme") apply_extreme ;;
					"normal") apply_normal ;;
					"saver"|"tasarruf") apply_saver ;;
					"auto")
							# Simply ask PPD what mode we are in (if PPD auto-switches)
							CURRENT=$(powerprofilesctl get)
							if [ "$CURRENT" = "performance" ]; then apply_gaming;
							elif [ "$CURRENT" = "power-saver" ]; then apply_saver;
							else apply_normal; fi
							;;
					*)
							echo "Usage: $0 {gaming|turbo|extreme|normal|saver|auto}"
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
				{ command = "${pkgs.linuxPackages_latest.cpupower}/bin/cpupower"; options = [ "NOPASSWD" ]; }
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
