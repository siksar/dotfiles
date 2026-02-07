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
    ${pkgs.btop}/bin/btop 2>/dev/null || ${pkgs.htop}/bin/htop
  '';

in
{
  # =============================================================================
  # NIX DAEMON OPTIMIZATION
  # =============================================================================

  nix = {
    settings = {
      # Parallel builds - use all performance cores
      max-jobs = lib.mkDefault maxJobs;
      cores = lib.mkDefault buildCores;

      # Parallel downloads
      download-threads = lib.mkDefault 8;

      # Build settings
      sandbox = lib.mkDefault true;

      # Store optimization
      auto-optimise-store = lib.mkDefault true;

      # Keep outputs and derivations for faster rebuilds
      keep-outputs = lib.mkDefault true;
      keep-derivations = lib.mkDefault true;

      # Experimental features
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
        "ca-derivations"
      ];

      # Fallback to source if binary cache fails
      fallback = lib.mkDefault true;
    };

    # Garbage collection
    gc = lib.mkDefault {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    # Store optimization
    optimise = lib.mkDefault {
      automatic = true;
      dates = [ "weekly" ];
    };

    # Extra options (string format)
    extraOptions = ''
      http-connections = 50
      log-lines = 25
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
    };
  };

  # =============================================================================
  # BUILD ENVIRONMENT
  # =============================================================================

  # Create build directory on tmpfs for speed
  systemd.tmpfiles.rules = [
    "d /tmp/nix-build 0755 root root -"
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

    # Custom optimized wrappers
    nixBuildOptimized
    nixDevelopOptimized
    nixStoreOptimize
    nixBuildMonitor

    # Build tools
    ccache                # Compiler cache

    # Monitoring
    btop                  # System monitor

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
  };

  # =============================================================================
  # DIRENV INTEGRATION
  # =============================================================================

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = false;
  };

  # =============================================================================
  # SHELL ALIASES
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
    alias nb='nix-build-opt'
    alias nd='nix-develop-opt'
    alias rebuild='sudo nixos-rebuild switch --flake .#nixos'
    alias nix-gc='nix-collect-garbage --delete-older-than 7d'
  '';

  # =============================================================================
  # ENVIRONMENT VARIABLES
  # =============================================================================

  environment.sessionVariables = {
    # Nix settings
    "NIX_BUILD_CORES" = toString buildCores;
    "NIX_MAX_JOBS" = toString maxJobs;

    # CCache
    "CCACHE_DIR" = "/var/cache/ccache";
    "CCACHE_COMPRESS" = "1";

    # Build directory
    "TMPDIR" = "/tmp";
    "NIX_BUILD_DIR" = "/tmp/nix-build";

    # Compiler flags for faster builds
    "MAKEFLAGS" = "-j${toString maxJobs}";
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

    ## Quick Commands

    ### Building
    ```bash
    # Optimized build
    nix-build-opt .#package

    # System rebuild
    rebuild           # Full rebuild
    rebuild-test      # Test configuration
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
  '';
}
