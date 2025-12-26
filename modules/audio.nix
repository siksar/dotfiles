{ config, pkgs, ... }:

{
  # ========================================================================
  # AUDIO STACK - PipeWire with Low Latency
  # ========================================================================
  
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    
    alsa = {
      enable = true;
      support32Bit = true;
    };
    
    pulse.enable = true;
    jack.enable = true;
    
    # Low latency configuration for gaming
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock.rate = 48000;
        default.clock.quantum = 256;
        default.clock.min-quantum = 128;
        default.clock.max-quantum = 512;
      };
    };
  };

  # Bluetooth audio
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
}
