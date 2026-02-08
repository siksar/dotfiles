{ config, pkgs, ... }:

{
  # ========================================================================
  # USER GAMING CONFIGURATION
  # ========================================================================
  
  home.packages = with pkgs; [
    # Game launchers
    lutris
    heroic
    bottles
    
    # Steam is system-level
    # Proton tools
    protontricks
    winetricks
    
    # Performance
    mangohud
    goverlay
    vkbasalt
    libstrangle
    
    # Monitoring
    nvtopPackages.nvidia
    radeontop
    
    # Utilities
    gamescope
    
    # Controller
    antimicrox
    sc-controller
  ];

  # ========================================================================
  # MANGOHUD CONFIG
  # ========================================================================
  home.file.".config/MangoHud/MangoHud.conf".text = ''
    ### MangoHud Configuration ###
    
    # Position
    position=top-left
    
    # Display
    fps
    frametime
    frame_timing
    
    # CPU
    cpu_stats
    cpu_temp
    cpu_power
    cpu_mhz
    cpu_load_change
    cpu_color=2E97CB
    
    # GPU
    gpu_stats
    gpu_temp
    gpu_power
    gpu_core_clock
    gpu_mem_clock
    gpu_load_change
    gpu_color=2E9762
    
    # Memory
    vram
    vram_color=AD64C1
    ram
    ram_color=C26693
    
    # System
    battery
    battery_icon
    battery_color=FF00FF
    
    # Engine
    engine_version
    engine_color=EB5B5B
    
    # Wine
    wine
    
    # Other
    resolution
    show_fps_limit
    arch
    
    # HUD Settings
    font_size=18
    font_scale=1.0
    font_scale_media_player=0.55
    background_alpha=0.3
    alpha=1.0
    
    # Toggle
    toggle_hud=Shift_R+F12
    toggle_fps_limit=Shift_L+F1
    
    # Logging
    log_duration=30
    autostart_log=0
    
    # Media Player
    media_player
    media_player_name=spotify
    
    # Presets
    preset=0
    
    # No display
    no_display
  '';

  # ========================================================================
  # VKBASALT CONFIG
  # ========================================================================
  home.file.".config/vkBasalt/vkBasalt.conf".text = ''
    # vkBasalt configuration
    
    # Effects
    effects = cas:fxaa
    
    # CAS (Contrast Adaptive Sharpening)
    casSharpness = 0.4
    
    # FXAA
    fxaaQualitySubpix = 0.75
    fxaaQualityEdgeThreshold = 0.166
    fxaaQualityEdgeThresholdMin = 0.0833
    
    # Reshade FX path
    reshadeTexturePath = "${config.xdg.configHome}/vkBasalt/textures"
    reshadeIncludePath = "${config.xdg.configHome}/vkBasalt/shaders"
    
    # Depth capture
    depthCapture = off
  '';

  # ========================================================================
  # GAMESCOPE CONFIG
  # ========================================================================
  home.file.".config/gamescope/config.conf".text = ''
    # Gamescope configuration
    
    # Resolution
    width=1920
    height=1080
    
    # Refresh rate
    refresh=144
    
    # Adaptive sync (VRR)
    adaptive-sync
    
    # Prefer external GPU
    prefer-vk-device
    
    # Real-time scheduling
    rt
    
    # HDR (if supported)
    # hdr-enabled
  '';

  # ========================================================================
  # LUTRIS CONFIG
  # ========================================================================
  home.file.".config/lutris/lutris.conf".text = ''
    [lutris]
    migration_version = 12
    show_advanced_options = true
    
    [services]
    lutris = true
    gog = false
    humblebundle = false
    steam = false
    
    [system]
    game_path = ~/Games
    runner_path = ~/.local/share/lutris/runners
    cache_path = ~/.cache/lutris
    
    [runners]
    wine = true
    proton = true
    
    [wine]
    version = lutris-GE-Proton8-26-x86_64
    dxvk_version = v2.3
    vkd3d_version = v2.10
  '';

  # ========================================================================
  # SHELL ALIASES
  # ========================================================================
  home.shellAliases = {
    # Gaming shortcuts
    "steam-gamemode" = "gamemoderun steam";
    "lutris-gamemode" = "gamemoderun lutris";
    "heroic-gamemode" = "gamemoderun heroic";
    
    # Gamescope shortcuts
    "gamescope-fhd" = "gamescope -W 1920 -H 1080 -r 144 --";
    "gamescope-2k" = "gamescope -W 2560 -H 1440 -r 144 --";
    "gamescope-4k" = "gamescope -W 3840 -H 2160 -r 60 --";
    
    # Performance
    "mango" = "mangohud --dlsym";
    "mango-gpu" = "MANGOHUD=1 mangohud --dlsym";
    
    # Monitoring
    "gpu-top" = "nvtop";
    "gpu-amd" = "radeontop";
  };

  # ========================================================================
  # DESKTOP ENTRIES
  # ========================================================================
  xdg.desktopEntries = {
    steam-gamemode = {
      name = "Steam (GameMode)";
      genericName = "Game Store";
      exec = "gamemoderun steam %U";
      icon = "steam";
      terminal = false;
      categories = [ "Game" "Network" ];
      mimeType = [ "x-scheme-handler/steam" "x-scheme-handler/steamlink" ];
    };
    
    lutris-gamemode = {
      name = "Lutris (GameMode)";
      genericName = "Game Launcher";
      exec = "gamemoderun lutris %U";
      icon = "lutris";
      terminal = false;
      categories = [ "Game" ];
    };
  };

  # ========================================================================
  # ENVIRONMENT VARIABLES
  # ========================================================================
  home.sessionVariables = {
    # Mangohud
    MANGOHUD = "1";
    MANGOHUD_CONFIGFILE = "${config.xdg.configHome}/MangoHud/MangoHud.conf";
    
    # VKBasalt
    ENABLE_VKBASALT = "1";
    VKBASALT_CONFIG_FILE = "${config.xdg.configHome}/vkBasalt/vkBasalt.conf";
    
    # DXVK
    DXVK_HUD = "compiler";
    DXVK_ASYNC = "1";
    DXVK_STATE_CACHE = "1";
    
    # Proton
    PROTON_ENABLE_NVAPI = "1";
    PROTON_HIDE_NVIDIA_GPU = "0";
    PROTON_USE_WINED3D = "0";
    
    # Gamescope
    GAMESCOPE_CONFIG = "${config.xdg.configHome}/gamescope/config.conf";
  };

  # ========================================================================
  # AUTOSTART
  # ========================================================================
  # No autostart for gaming apps
}
