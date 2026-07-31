# Ses: PipeWire (PulseAudio kapalı) + rtkit gerçek-zamanlı öncelik.
{ ... }:

{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable         = true;
    alsa.enable    = true;
    alsa.support32Bit = true;
    pulse.enable   = true;
  };
}
