# Starship prompt. Renkler ANSI adıyla verilir, hex değil — Stylix terminal paletine eşler.
{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      format = "$nix_shell$cmd_duration$character";

      nix_shell = {
        symbol = " ";
        style = "cyan";
        format = "[$symbol$state]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        style = "yellow";
        format = "[ $duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold cyan)";
      };
    };
  };
}
