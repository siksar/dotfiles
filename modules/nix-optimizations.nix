{ config, pkgs, lib, ... }:

let
  # Determine optimal build cores based on CPU topology
  # Strix Point: 4 Zen5 (perf) + 4 Zen5c (eff) = 8 cores, 16 threads
  totalCores = 16;
  performanceCores = 8;  # Zen 5 cores with SMT
  
  # Build optimization settings
  maxJobs = 8;           # Parallel builds
  buildCores = 4;        # Cores per build (for single derivation)
  
  # Nix build wrapper with CPU affinity
  nixBuildOptimized = pkgs.writeShellScriptBin "nix-build-opt" ''
    #!${pkgs.runtimeShell}
    
    # Use performance cores for building
    export NIX_BUILD_CORES=${toString buildCores}
    
    # Enable parallel downloads
    export NIX_PARALLEL_DOWNLOADS=8
    
    # Set build directory to fast storage if available
    if [ -d "/tmp/nix-build" ]; then
      export TMPDIR=/tmp/nix-build
    fi
    
    # Run nix build with performance optimizations
    exec ${pkgs.nix-output-monitor}/bin/nom build "$@" \
      --option cores ${toString buildCores} \
      --option max-jobs ${toString maxJobs} \
      --option parallel-downloads 8
  '';

  # Nix develop wrapper
  nixDevelopOptimized = pkgs.writeShellScriptBin "nix-develop-opt" ''
    #!${pkgs.runtimeShell}
    
    # Optimized nix develop
    exec nix develop "$@" \
      --option cores ${toString buildCores} \
      --option max-jobs ${toString maxJobs}
  '';

  # Store optimization script
  nixStoreOptimize = pkgs.writeShellScriptBin "nix-store-optimize" ''
    #!${pkgs.runtimeShell}
    
    echo "=== Nix Store Optimization ==="
    
    # Garbage collect
    echo "Running garbage collection..."
    nix-collect-garbage --delete-older-than 7d
    
    # Optimize store (deduplication)
    echo "Optimizing store..."
    nix-store --optimise
    
    # Verify store
    echo "Verifying store..."
    nix-store --verify --check-contents
    
    # Show store stats
    echo ""
    echo "=== Store Statistics ==="
    nix path-info -Sh /run/current-system | head -5
    
    # Disk usage
    echo ""
    echo "=== Disk Usage ==="
    du -sh /nix/store
    du -sh /nix/var
  '';

  # Build performance monitor
  nixBuildMonitor = pkgs.writeShellScriptBin "nix-build-mon" ''
    #!${pkgs.runtimeShell}
    
    # Monitor nix builds with system resources
    ${pkgs.btop}/bin/btop --preset nix-build 2>/dev/null || ${pkgs.htop}/bin/htop
  '';

in
{
  # =============================================================================
  # NIX DAEMON OPTIMIZATION
  # =============================================================================
  
  nix = {
    settings = {
      # Parallel builds - use all performance cores
      max-jobs = maxJobs;
      cores = buildCores;
      
      # Parallel downloads
      download-threads = 8;
      download-buffer-size = 512 * 1024 * 1024;  # 512MB buffer
      
      # Build settings
      sandbox = true;
      sandbox-fallback = false;
      
      # Store optimization
      auto-optimise-store = true;
      
      # Keep outputs and derivations for faster rebuilds
      keep-outputs = true;
      keep-derivations = true;
      
      # Build timeout (prevent stuck builds)
      build-timeout = 3600;  # 1 hour
      
      # Connect timeout for downloads
      connect-timeout = 30;
      
      # Stalled download timeout
      stalled-download-timeout = 300;
      
      # Pre-build hooks
      pre-build-hook = null;
      
      # Post-build hooks for signing
      post-build-hook = null;
      
      # Experimental features
      experimental-features = [ 
        "nix-command" 
        "flakes" 
        "ca-derivations"
        "impure-derivations"
        "recursive-nix"
      ];
      
      # Trusted users
      trusted-users = [ "root" "@wheel" "zixar" ];
      allowed-users = [ "*" ];
      
      # Substituters (binary caches)
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://chaotic-nyx.cachix.org"
        "https://cuda-maintainers.cachix.org"
        "https://ai.cachix.org"
      ];
      
      # Trusted public keys
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vFcUsQ="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rNqbDBO8NpdgaQcpGuPvGjTMJU="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        "ai.cachix.org-1:N9dzRK+alWwoKXQlnn0H6aUx0lUdos0l1f+JoJuvK4Y="
      ];
      
      # Fallback to source if binary cache fails
      fallback = true;
      
      # Show build trace
      show-trace = false;
      
      # Rebuild on lock file changes
      refresh = false;
    };
    
    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
      persistent = true;
    };
    
    # Store optimization
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    
    # Extra options
    extraOptions = ''
      # Build performance
      builders-use-substitutes = true
      
      # Network settings
      http-connections = 50
      
      # Binary cache settings
      binary-caches-parallel-connections = 50
      
      # Build log settings
      log-lines = 50
      
      # Build directory
      build-dir = /tmp/nix-build
      
      # Keep failed builds for debugging
      keep-failed = false
      
      # Build users group
      build-users-group = nixbld
    '';
  };

  # =============================================================================
  # NIX DAEMON SERVICE OPTIMIZATION
  # =============================================================================
  
  systemd.services.nix-daemon = {
    serviceConfig = {
      # CPU affinity - use efficiency cores for daemon
      CPUAffinity = "4-7,12-15";
      
      # Nice level
      Nice = 10;
      
      # IO scheduling
      IOSchedulingClass = "idle";
      IOSchedulingPriority = 7;
      
      # Memory limits
      MemoryMax = "4G";
      MemorySwapMax = "2G";
      
      # Restart policy
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # =============================================================================
  # BUILD ENVIRONMENT
  # =============================================================================
  
  # Create build directory on tmpfs for speed
  systemd.tmpfiles.rules = [
    "d /tmp/nix-build 0755 root root -"
    "d /tmp/nix-build-cache 0755 root root -"
  ];

  # =============================================================================
  # PACKAGES
  # =============================================================================
  
  environment.systemPackages = with pkgs; [
    # Nix tools
    nix-output-monitor    # Better nix build output
    nix-tree              # Visualize nix store dependencies
    nix-diff              # Compare nix derivations
    nix-index             # Index nix packages
    nixpkgs-fmt           # Nix formatter
    nixpkgs-review        # Review nixpkgs PRs
    
    # Custom optimized wrappers
    nixBuildOptimized
    nixDevelopOptimized
    nixStoreOptimize
    nixBuildMonitor
    
    # Build tools
    ccache                # Compiler cache
    ccacheWrapper         # CC wrapper with ccache
    distcc                # Distributed compilation
    
    # Monitoring
    btop                  # System monitor
    iotop                 # IO monitor
    nethogs               # Network monitor
    
    # Development
    direnv                # Directory environment
    nix-direnv            # Better direnv for nix
  ];

  # =============================================================================
  # CCACHE CONFIGURATION
  # =============================================================================
  
  programs.ccache = {
    enable = true;
    cacheDir = "/var/cache/ccache";
    maxSize = "50G";
    
    # Package overrides to use ccache
    packageNames = [
      "linux"
      "linux_latest"
      "linux_zen"
    ];
  };

  # =============================================================================
  # BUILD HOOKS
  # =============================================================================
  
  # Pre-build hook for logging
  nix.settings.pre-build-hook = pkgs.writeShellScript "nix-pre-build" ''
    #!${pkgs.runtimeShell}
    echo "[NIX BUILD] Starting: $OUT"
  '';

  # =============================================================================
  # SHELL CONFIGURATION
  # =============================================================================
  
  programs.zsh.interactiveShellInit = ''
    # Nix completion
    fpath+=${pkgs.nix-zsh-completions}/share/zsh/site-functions
    
    # Nix aliases
    alias nb='nix-build-opt'
    alias nd='nix-develop-opt'
    alias ns='nix search nixpkgs'
    alias nf='nix flake'
    alias nfu='nix flake update'
    alias nfc='nix flake check'
    alias nsh='nix shell'
    alias nso='nix-store-optimize'
    
    # Fast rebuild
    alias rebuild='sudo nixos-rebuild switch --flake .#nixos'
    alias rebuild-test='sudo nixos-rebuild test --flake .#nixos'
    alias rebuild-boot='sudo nixos-rebuild boot --flake .#nixos'
    
    # Build with monitoring
    alias rebuild-mon='sudo nom build .#nixosConfigurations.nixos.config.system.build.toplevel && sudo nixos-rebuild switch --flake .#nixos'
    
    # Garbage collection
    alias nix-gc='nix-collect-garbage --delete-older-than 7d'
    alias nix-gc-all='nix-collect-garbage --delete-old'
    
    # Store operations
    alias nix-size='nix path-info -Sh'
    alias nix-why='nix why-depends'
    alias nix-tree='nix-tree'
  '';

  # Bash support
  programs.bash.interactiveShellInit = ''
    # Nix aliases
    alias nb='nix-build-opt'
    alias nd='nix-develop-opt'
    alias ns='nix search nixpkgs'
    alias nf='nix flake'
    alias nfu='nix flake update'
    alias nfc='nix flake check'
    alias nsh='nix shell'
    alias nso='nix-store-optimize'
    alias rebuild='sudo nixos-rebuild switch --flake .#nixos'
    alias nix-gc='nix-collect-garbage --delete-older-than 7d'
  '';

  # =============================================================================
  # DIRENV INTEGRATION
  # =============================================================================
  
  programs.direnv = {
    enable = true;
    nix-direnv = {
      enable = true;
      # Enable flakes support
    };
    
    # Silent mode
    silent = false;
    
    # Load timeout
    loadTimeout = "5s";
  };

  # =============================================================================
  # ENVIRONMENT VARIABLES
  # =============================================================================
  
  environment.sessionVariables = {
    # Nix settings
    "NIX_BUILD_CORES" = toString buildCores;
    "NIX_MAX_JOBS" = toString maxJobs;
    "NIX_PARALLEL_DOWNLOADS" = "8";
    
    # CCache
    "CCACHE_DIR" = "/var/cache/ccache";
    "CCACHE_MAXSIZE" = "50G";
    "CCACHE_COMPRESS" = "1";
    
    # Build directory
    "TMPDIR" = "/tmp";
    "NIX_BUILD_DIR" = "/tmp/nix-build";
    
    # Compiler flags for faster builds
    "MAKEFLAGS" = "-j${toString maxJobs}";
    "CMAKE_BUILD_PARALLEL_LEVEL" = toString maxJobs;
    "NINJAFLAGS" = "-j${toString maxJobs}";
    
    # Rust parallel compilation
    "CARGO_BUILD_JOBS" = toString buildCores;
    "RUSTFLAGS" = "-C target-cpu=native";
  };

  # =============================================================================
  # SYSTEM-WIDE BUILD CONFIGURATION
  # =============================================================================
  
  # Make flags for system builds
  environment.variables = {
    NIX_CFLAGS_COMPILE = "-O3 -march=native -mtune=native";
    NIX_CXXFLAGS_COMPILE = "-O3 -march=native -mtune=native";
    NIX_LDFLAGS = "";
  };

  # =============================================================================
  # DOCUMENTATION
  # =============================================================================
  
  environment.etc."nix-optimizations/README.md".text = ''
    # Nix Build Optimizations
    
    ## Configuration
    - **Max Jobs**: ${toString maxJobs} parallel builds
    - **Build Cores**: ${toString buildCores} cores per build
    - **Download Threads**: 8 parallel downloads
    - **Download Buffer**: 512MB
    
    ## Quick Commands
    
    ### Building
    ```bash
    # Optimized build
    nix-build-opt .#package
    
    # With monitoring
    nom build .#package
    
    # System rebuild
    rebuild           # Full rebuild
    rebuild-test      # Test configuration
    rebuild-mon       # Build with monitoring
    ```
    
    ### Development Shell
    ```bash
    # Optimized nix develop
    nix-develop-opt
    
    # Or use direnv
    echo "use flake" > .envrc && direnv allow
    ```
    
    ### Store Management
    ```bash
    nix-store-optimize    # Optimize store
    nix-gc               # Garbage collect
    nix-gc-all           # Aggressive GC
    nix-tree             # Visualize dependencies
    ```
    
    ## Performance Tips
    
    1. **Use Binary Caches**: Configured caches for common packages
    2. **Enable CCache**: Compiler caching for repeated builds
    3. **Tmpfs Build Dir**: Fast in-memory builds
    4. **Parallel Downloads**: 8 concurrent downloads
    5. **CPU Affinity**: Build daemon uses efficiency cores
    
    ## Monitoring
    ```bash
    nix-build-mon        # Monitor builds
    btop                 # System monitor
    iotop                # IO monitor
    ```
    
    ## Troubleshooting
    
    ### Slow Builds
    - Check CPU affinity: `systemctl show nix-daemon -p CPUAffinity`
    - Monitor resources: `btop`
    - Clear build cache: `rm -rf /tmp/nix-build/*`
    
    ### Out of Space
    ```bash
    nix-collect-garbage --delete-older-than 3d
    nix-store --optimise
    ```
    
    ### Build Failures
    ```bash
    # Keep failed build
    nix-build --keep-failed
    
    # Check build log
    nix log /nix/store/...-package
    ```
  '';

  # =============================================================================
  # NOTES
  # =============================================================================
  
  # For distributed builds, add to nix.settings.builders:
  # "ssh://user@builder x86_64-linux,i686-linux - 8 2 kvm,benchmark"
}
