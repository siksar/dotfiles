{ pkgs, ... }:

let
  # Limiter: swh-plugins (LADSPA). LSP aynı işi +166 MiB'la yapıyordu.
  limiterPlugin = "${pkgs.ladspaPlugins}/lib/ladspa/fast_lookahead_limiter_1913.so";

  # builtin bq_* eklentileri MONO → L/R için ayrı düğüm.
  chan = ch: [
    { type = "builtin"; name = "hp_${ch}";   label = "bq_highpass";
      control = { "Freq" = 90.0;   "Q" = 0.7; "Gain" = 0.0; }; }

    { type = "builtin"; name = "bass_${ch}"; label = "bq_peaking";
      control = { "Freq" = 130.0;  "Q" = 1.0; "Gain" = 5.0; }; }

    { type = "builtin"; name = "pres_${ch}"; label = "bq_peaking";
      control = { "Freq" = 3000.0; "Q" = 0.9; "Gain" = 2.5; }; }
  ];

  chanLinks = ch: [
    { output = "hp_${ch}:Out";   input = "bass_${ch}:In"; }
    { output = "bass_${ch}:Out"; input = "pres_${ch}:In"; }
  ];
in
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable         = true;
    alsa.enable    = true;
    alsa.support32Bit = true;
    pulse.enable   = true;

    # 44.1 kHz başlangıç; içerik geldiğinde graf uygun hıza geçer.
    extraConfig.pipewire."10-dac-quality" = {
      "context.properties" = {
        "default.clock.rate" = 44100;
        "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
      };
    };

  # Hoparlör DSP zinciri: ALC245 çıplak çalıyor (amfi DSP'si/SOF yok).
  # high-pass 90Hz → bas +5dB@130 → presence +2.5dB@3k → swh limiter.
  # Hedef UCM'in Speaker sink'i: kulaklık etkilenmez.
    extraConfig.pipewire."99-hoparlor-dsp" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          args = {
            "node.description" = "Hoparlör (DSP)";
            "media.name"       = "Hoparlör (DSP)";

            "filter.graph" = {
              nodes = chan "l" ++ chan "r" ++ [
                {
                  type   = "ladspa";
                  name   = "lim";
                  plugin = limiterPlugin;
                  label  = "fastLookaheadLimiter";
                  control = {
                    # >>> SESİ AÇAN/KISAN DÜĞME BU (aralık -20 .. +20 dB).
                    # Sinyali limiter eşiğinin içine iter: tepe noktaları
                    # bastırılırken altındaki her şey yukarı çıkar, algısal
                    # yükseklik buradan gelir. Az geliyorsa 7-8'e çık; 808'lerde
                    # eziklik ya da pompalama duyarsan geri in.
                    "Input gain (dB)"  = 5.0;

                    "Limit (dB)"       = -1.0;

                    "Release time (s)" = 0.05;
                  };
                }
              ];

              links = chanLinks "l" ++ chanLinks "r" ++ [
                { output = "pres_l:Out"; input = "lim:Input 1"; }
                { output = "pres_r:Out"; input = "lim:Input 2"; }
              ];

              inputs  = [ "hp_l:In" "hp_r:In" ];
              outputs = [ "lim:Output 1" "lim:Output 2" ];
            };

            "capture.props" = {
              "node.name"        = "effect_input.hoparlor";
              "media.class"      = "Audio/Sink";
              "audio.channels"   = 2;
              "audio.position"   = [ "FL" "FR" ];
              # Gerçek hoparlör sink'i 1000'de; 2000 → WirePlumber bunu varsayılan seçer.
              "priority.session" = 2000;
            };

            # target.object ŞART: yoksa çıkış varsayılan sink'i (bu zincir) arar, graf kendine bağlanır.
            "playback.props" = {
              "node.name"      = "effect_output.hoparlor";
              "node.passive"   = true;
              "audio.channels" = 2;
              "audio.position" = [ "FL" "FR" ];
              "target.object"  = "alsa_output.pci-0000_65_00.6.HiFi__Speaker__sink";
            };
          };
        }
      ];
    };
  };
}
