{ pkgs, ... }:
{
	home.packages = with pkgs; [
		# Media TUI Tools
		ytfzf         # Youtube CLI
		ncmpcpp       # MPD client
		cava          # Audio visualizer
		# lrcget      # Lyrics (replaces lrcsnc)
		# deemix-gui/deemix might be in chaotic or custom, 
		# assuming they are available or adding common alternatives
		ani-cli
		mangal
		youtube-tui
	];
}
