{ config, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = false;
    
    settings = builtins.fromTOML ''
      # Created by JDXE
      # Adapted to Miasma Theme (NixOS Logo Added)
      # Miasma Colors: Gold #c9a554, Copper #b36d43, Rust #bb7744, Bg #222222, Fg #c2c2b0

      "$schema" = 'https://starship.rs/config-schema.json'

      format = """
      [](colour_ff9d4d)\
      $os\
      $username\
      [](bg:colour_ffaa71 fg:colour_ff9d4d)\
      $directory\
      [](fg:colour_ffaa71 bg:colour_ffbe8d)\
      $git_branch\
      $git_status\
      [](fg:colour_ffbe8d bg:colour_ffc9ad)\
      $c\
      $rust\
      $golang\
      $nodejs\
      $php\
      $java\
      $kotlin\
      $haskell\
      $python\
      [](fg:colour_ffc9ad bg:colour_ffe0d2)\
      $docker_context\
      $conda\
      [](fg:colour_ffe0d2 bg:color_bg1)\
      $time\
      [ ](fg:color_bg1)\
      $character"""

      palette = 'miasma'

      [palettes.miasma]
      colour_foreground = '#222222' # Dark text on light backgrounds
      color_bg1 = '#222222'       # Background color (Dark Grey)
      colour_ffe0d2 = '#f0e0b0'   # Brightest Cream
      colour_ffc9ad = '#d7c483'   # Cream Gold
      colour_ffbe8d = '#c9a554'   # Primary Gold
      colour_arrow = '#c9a554'    # Accent Gold
      colour_ff9d4d = '#b36d43'   # Copper
      colour_FF5C00 = '#bb7744'   # Secondary/Rust
      color_red = '#8a6f5c'       # Miasma Red
      colour_ffaa71 = '#bb7744'   # Rust (Gradient Middle)

      [os]
      disabled = false
      style = "bg:colour_ff9d4d fg:colour_foreground"

      [os.symbols]
      NixOS = " "
      Windows = ""
      Ubuntu = ""
      SUSE = ""
      Raspbian = ""
      Mint = ""
      Macos = ""
      Manjaro = ""
      Linux = ""
      Gentoo = ""
      Fedora = ""
      Alpine = ""
      Amazon = ""
      Android = ""
      Arch = ""
      Artix = ""
      EndeavourOS = ""
      CentOS = ""
      Debian = ""
      Redhat = ""
      RedHatEnterprise = ""

      [username]
      show_always = true
      style_user = "bg:colour_ff9d4d fg:colour_foreground"
      style_root = "bg:colour_ff9d4d fg:colour_foreground"
      format = '[ $user ]($style)'

      [directory]
      style = "fg:colour_foreground bg:colour_ffaa71"
      format = "[ $path ]($style)"
      truncation_length = 3
      truncation_symbol = "…/"

      [directory.substitutions]
      "Documents" = " "
      "Downloads" = " "
      "Music" = " "
      "Pictures" = " "
      "Developer" = " "

      [git_branch]
      symbol = ""
      style = "bg:colour_ffbe8d"
      format = '[[ $symbol $branch ](fg:colour_foreground bg:colour_ffbe8d)]($style)'

      [git_status]
      style = "bg:colour_ffbe8d"
      format = '[[($all_status$ahead_behind )](fg:colour_foreground bg:colour_ffbe8d)]($style)'

      [nodejs]
      symbol = ""
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [c]
      symbol = " "
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [rust]
      symbol = ""
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [golang]
      symbol = ""
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [php]
      symbol = ""
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [java]
      symbol = " "
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [kotlin]
      symbol = ""
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [haskell]
      symbol = ""
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [python]
      symbol = ""
      style = "bg:colour_ffc9ad"
      format = '[[ $symbol( $version) ](fg:colour_foreground bg:colour_ffc9ad)]($style)'

      [docker_context]
      symbol = ""
      style = "bg:colour_ffe0d2"
      format = '[[ $symbol( $context) ](fg:#83a598 bg:colour_ffe0d2)]($style)'

      [conda]
      style = "bg:colour_ffe0d2"
      format = '[[ $symbol( $environment) ](fg:#83a598 bg:colour_ffe0d2)]($style)'

      [time]
      disabled = false
      time_format = "%R"
      style = "bg:color_bg1"
      format = '[[  $time ](fg:#c2c2b0 bg:color_bg1)]($style)'

      [line_break]
      disabled = false

      [character]
      disabled = false
      success_symbol = '[ 〉](bold fg:colour_arrow)'
      error_symbol = '[ 〉](bold fg:color_red)'
      vimcmd_symbol = '[〈](bold fg:colour_arrow)'
      vimcmd_replace_one_symbol = '[〈](bold fg:colour_FF5C00)'
      vimcmd_replace_symbol = '[〈](bold fg:colour_FF5C00)'
      vimcmd_visual_symbol = '[〈](bold fg:colour_ffaa71)'
    '';
  };
}
