# Quickshell - QML/JS Wayland compositor (isteğe bağlı)
# Aktif etmek için: flake veya configuration.nix imports'a ekle ve quickshell.enable = true yap.
{ config, pkgs, lib, ... }:

let
	cfg = config.quickshell;
in
{
	options.quickshell = {
		enable = lib.mkEnableOption "Quickshell Wayland compositor (QML/JS)";
	};

	config = lib.mkIf cfg.enable {
		environment.systemPackages = [ pkgs.quickshell ];

		# İsteğe bağlı: GreetD'de Quickshell oturumu (Hyprland yanında)
		# Açmak için services.greetd.settings.default_session.command = "Quickshell" gibi override gerekir.
		# Şu an sadece paket eklenir; oturum seçimi manuel veya ayrı bir profile bırakıldı.
	};
}
