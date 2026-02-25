{ pkgs, config, ... }:
{
	home.packages = with pkgs; [
		# Media TUI Tools
		ytfzf         # Youtube CLI
		ncmpcpp       # MPD client
		cava          # Audio visualizer
		lrcsnc        # Player-agnostic synced lyrics
		python3Packages.deemix # Deezer downloader
		ani-cli       # Anime CLI
		mangal        # Manga CLI
		youtube-tui   # YouTube TUI
	];

	services.mpd = {
		enable = true;
		musicDirectory = "${config.home.homeDirectory}/Music/deemix Music";
		extraConfig = ''
			audio_output {
				type "pipewire"
				name "My PipeWire Output"
			}
		'';
	};

	services.mpd-mpris.enable = true;

	programs.ncmpcpp = {
		enable = true;
		mpdMusicDir = "${config.home.homeDirectory}/Music/deemix Music";
	};
}
