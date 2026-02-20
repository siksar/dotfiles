{ config, pkgs, inputs, lib, ... }:

{
	# ========================================================================
	# BROWSERS CONFIGURATION (Zen & Ungoogled Chromium)
	# ========================================================================
  
	# Zen Browser Package (from Flake input)
	home.packages = [
		inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
	];

	# ========================================================================
	# UNGOOGLED CHROMIUM (Privacy & Bypass Optimized)
	# ========================================================================
	programs.chromium = {
		enable = true;
		package = pkgs.ungoogled-chromium;
    
		# Extensions
		extensions = [
			{ id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
			{ id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader
			{ id = "gjoijpfmdhbjkkgnmahganhoinjjpgke"; } # YouTube Screenshot
			{ id = "gdocmgbfkjnnpapjnkbgcmhfppjklaan"; } # Cookies.txt
			{ id = "mefgmmbdailogpfhfbljmjdgbhebeboh"; } # Feedbro (RSS)
			{ id = "ecklbbmainhkfhlcglcdkndbpeopjicp"; } # Startpage - Private Search
			{ id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden Password Manager
		];
    
		commandLineArgs = [
			# Privacy & Anti-Fingerprinting
			"--disable-features=WebRtcHideLocalIpsWithMdns"
			"--no-default-browser-check"
			"--disable-reading-from-canvas"
			"--no-pings"
			"--enable-do-not-track" # Do Not Track request
			"--force-https" # Always confirm secure connection (if supported by wrapper)
      
			# Security & Censorship Bypass
			"--enable-features=EncryptedClientHello,HttpsOnlyMode"
			"--dns-over-https=https://dns.nextdns.io"
      
			# Performance (Memory Saver & Preloading)
			# HighEfficiencyMode = Memory Saver. Prerender2 = Extended Preloading.
			"--enable-features=HighEfficiencyModeAvailable,HighEfficiencyMode,Prerender2"
			"--memory-saver-mode-aggressiveness=conservative" # Maximize effect (default/conservative/aggressive)
      
			# UI & Theme (Miasma-like Dark Mode & System Integration)
			"--use-system-title-bar" # System bar and borders
			"--force-dark-mode" # Force dark mode for UI
			"--restore-last-session" # Continue where you left off
      
			# Toolbar Features (Enabled via flags where possible)
			# ReadingList, SidePanel, SharingQRCodeGenerator are often default but ensuring enabled
			"--enable-features=ReadLater,SidePanel,SharingQRCodeGenerator,TabSearch"
		];
	};

	# ========================================================================
	# ZEN BROWSER SETTINGS (User.js - Deep Privacy & Bypass)
	# ========================================================================
	# This template enables configurations similar to 'GoodbyeDPI' effects 
	# achievable at the browser level (ECH + DoH + HTTP3).
  
	home.file.".zen/user.js.template".text = ''
		// =========================================================================
		// ZEN BROWSER / FIREFOX HARDENING & BYPASS CONFIGURATION
		// =========================================================================

		// --- DPI BYPASS & ANTI-CENSORSHIP (GoodbyeDPI Style) ---
    
		// 1. Encrypted Client Hello (ECH)
		// Encrypts the Server Name Indication (SNI), hiding the destination hostname from the ISP.
		user_pref("network.dns.echconfig.enabled", true);
		user_pref("network.dns.http3_echconfig.enabled", true);
    
		// 2. DNS over HTTPS (DoH)
		// Encrypts DNS requests so they can't be snooped or blocked.
		// Using NextDNS (Mode 2 = Preferred)
		user_pref("network.trr.mode", 2); 
		user_pref("network.trr.uri", "https://dns.nextdns.io");
		user_pref("network.trr.bootstrapAddress", "45.90.28.0");
		// Only send DNS requests, don't fallback to unencrypted immediately if possible (Mode 3 is strict)
		// user_pref("network.trr.mode", 3); // Uncomment for strict mode (might break captive portals)

		// 3. HTTP3 / QUIC
		// Uses UDP instead of TCP, often bypassing TCP-based blocking/throttling systems.
		user_pref("network.http.http3.enable", true);
    
		// --- PRIVACY & FINGERPRINTING ---
    
		// 1. Resist Fingerprinting
		// Masks system info. Note: May break timezone apps or canvas-heavy sites.
		user_pref("privacy.resistFingerprinting", false); // Set to true for max privacy
		user_pref("privacy.fingerprintingProtection", true); // Newer isolated approach (better compatibility)
    
		// 2. Tracking Protection
		user_pref("privacy.trackingprotection.enabled", true);
		user_pref("privacy.trackingprotection.socialtracking.enabled", true);
		user_pref("privacy.partition.network_state", true); // Cache isolation

		// 3. Telemetry & Pocket (Disable bloat)
		user_pref("datareporting.healthreport.uploadEnabled", false);
		user_pref("datareporting.policy.dataSubmissionEnabled", false);
		user_pref("extensions.pocket.enabled", false);
    
		// --- SECURITY ---
		// Post-Quantum Cryptography (Kyber)
		user_pref("security.pqc.kyber.enabled", true);
	'';

	# ========================================================================
	# DEFAULT BROWSER (XDG)
	# ========================================================================
	xdg.mimeApps.defaultApplications = {
		"text/html" = "zen.desktop";
		"x-scheme-handler/http" = "zen.desktop";
		"x-scheme-handler/https" = "zen.desktop";
		"x-scheme-handler/about" = "zen.desktop";
		"x-scheme-handler/unknown" = "zen.desktop";
	};
}
