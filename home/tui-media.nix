{ pkgs, ... }:
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
}
