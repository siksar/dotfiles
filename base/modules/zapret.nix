{ config, pkgs, lib, ... }:

# ============================================================================
# ZAPRET - Minimal DPI Bypass (GoodbyeDPI alternative for Linux)
# ============================================================================
# Bu modül, DPI (Deep Packet Inspection) bypass için minimal yapılandırma sağlar.
# YouTube, Discord, Twitter vb. sitelere erişim için kullanılır.
# ============================================================================

let
	# Zapret binary'lerini nix-community/nur veya doğrudan derle
	zapret = pkgs.stdenv.mkDerivation rec {
		pname = "zapret";
		version = "70";
    
		src = pkgs.fetchFromGitHub {
			owner = "bol-van";
			repo = "zapret";
			rev = "v${version}";
			hash = "sha256-ywqJ44WN0UmZEVUlghuBDSdeaBpf7F8KjrcKSwx/ATI=";
		};

		nativeBuildInputs = with pkgs; [ pkg-config ];
		buildInputs = with pkgs; [ 
			libnetfilter_queue 
			libnfnetlink 
			libcap 
			zlib 
		];

		buildPhase = ''
			# Build nfqws
			cd nfq && make && cd ..
			# Build tpws  
			cd tpws && make && cd ..
		'';

		installPhase = ''
			mkdir -p $out/bin
			cp nfq/nfqws $out/bin/
			cp tpws/tpws $out/bin/
		'';
	};

in
{
	# Paketler
	environment.systemPackages = [ zapret pkgs.iptables ];

	# Kernel modül
	boot.kernelModules = [ "nfnetlink_queue" ];

	# ========================================================================
	# NFQWS Service - YouTube/Discord/Twitter bypass
	# ========================================================================
	systemd.services.zapret = {
		description = "Zapret DPI Bypass";
		wantedBy = [ "multi-user.target" ];
		after = [ "network-online.target" ];
		wants = [ "network-online.target" ];

		# iptables kuralları başlamadan önce ekle
		preStart = ''
			${pkgs.iptables}/bin/iptables -t mangle -I POSTROUTING -p tcp --dport 443 -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || true
		'';

		serviceConfig = {
			Type = "simple";
			ExecStart = ''
				${zapret}/bin/nfqws \
					--qnum=200 \
					--dpi-desync=fake,split2 \
					--dpi-desync-ttl=4 \
					--dpi-desync-fooling=badsum
			'';
			ExecStopPost = ''
				${pkgs.iptables}/bin/iptables -t mangle -D POSTROUTING -p tcp --dport 443 -j NFQUEUE --queue-num 200 --queue-bypass 2>/dev/null || true
			'';
			Restart = "on-failure";
			RestartSec = 3;
		};
	};
}
