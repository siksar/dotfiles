# Ses: PipeWire (PulseAudio kapalı) + rtkit gerçek-zamanlı öncelik
#      + hoparlör DSP zinciri (filter-chain, EasyEffects'in yerine).
{ pkgs, ... }:

let
  # Limiter LADSPA eklentisi (swh-plugins / Steve Harris). Mutlak store yolu
  # veriyoruz ki LADSPA_PATH aramasına muhtaç olmayalım; string bağlamı
  # (string context) sayesinde paket sistem closure'ına bu referansla giriyor,
  # environment.systemPackages'a eklemeye gerek yok.
  # LSP DEĞİL: LSP'nin limiter'ı da işi görüyordu ama sisteme +166,5 MiB
  # ekliyordu (ölçüldü, 28 Ağu 2026) — GUI/VST/CLAP/LV2 paketlerinin tamamını
  # taşıdığı için. swh yalnız düz LADSPA .so'ları.
  limiterPlugin = "${pkgs.ladspaPlugins}/lib/ladspa/fast_lookahead_limiter_1913.so";

  # Tek kanallık biquad zinciri. builtin bq_* eklentileri MONO (1 giriş/1 çıkış),
  # bu yüzden L ve R için ayrı düğüm üretiyoruz — aşağıdaki fonksiyon o
  # tekrarı yazmamak için.
  # Port adları In/Out, kontrol adları Freq/Q/Gain: pipewire 1.6.8'in
  # libspa-filter-graph-plugin-builtin.so'sundan okunarak doğrulandı (28 Ağu 2026).
  chan = ch: [
    # Sürücünün fiziksel olarak üretemediği alt-bas: hoparlöre giden gücü
    # boşa harcamak yerine kesiyoruz — kesilen enerji limiter'a headroom olarak
    # geri dönüyor, yani ses aslında bu filtre YÜZÜNDEN yükseliyor.
    # 90 Hz, tek biquad = 12 dB/oct. (EasyEffects 100 Hz + slope x3 = 18 dB/oct
    # kullanıyordu; burada bir kademe daha alçak/yumuşak, 808'in temeli kalsın diye.)
    { type = "builtin"; name = "hp_${ch}";   label = "bq_highpass";
      control = { "Freq" = 90.0;   "Q" = 0.7; "Gain" = 0.0; }; }

    # Algısal bas ağırlığı. EasyEffects'teki bass_enhancer harmonik ÜRETİYORDU;
    # biquad bunu yapamaz, yapabileceği en yakın şey sürücünün gerçekten
    # çalabildiği bandı (~130 Hz) yukarı almak.
    { type = "builtin"; name = "bass_${ch}"; label = "bq_peaking";
      control = { "Freq" = 130.0;  "Q" = 1.0; "Gain" = 5.0; }; }

    # Vokal/adlib netliği — eski zincirdeki crystalizer'ın band0/band1 işi.
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

    # USB DAC / Deezer HiFi: 44.1 kHz'i (FLAC'ın doğal örnekleme hızı)
    # başlangıç hızı yap; 48/88.2/96 kHz içerik geldiğinde PipeWire'ın grafı
    # uygun hıza geçmesine izin ver. Böylece müzikte gereksiz 44.1 -> 48 kHz
    # dönüşümü yapılmaz, video ve sistem sesleri de çalışmaya devam eder.
    extraConfig.pipewire."10-dac-quality" = {
      "context.properties" = {
        "default.clock.rate" = 44100;
        "default.clock.allowed-rates" = [ 44100 48000 88200 96000 ];
      };
    };

  # ------------------------------------------------------------------------
  # Hoparlör DSP zinciri — NEDEN VAR
  #
  # ALC245 bu makinede AMD HDA veri yolu üzerinden ÇIPLAK çalıyor: akıllı amfi
  # DSP'si yok, SOF yok. Yani hoparlöre giden sinyale kimse dokunmuyor ve
  # 2 hoparlörlü bir laptopun ham tavanı düşük. 28 Ağu 2026'da EasyEffects
  # (home/apps/audio.nix) kaldırılınca ses "kısıldı" — çünkü o zincir bir
  # ekolayzer değil, bir YÜKSEKLİK MAKSİMİZÖRÜ'ydü: multiband_compressor'ın
  # bant başına 3-4 dB makeup'ı + bass_enhancer'ın 0.0'a çekilmiş input-gain'i
  # (kaynak preset -6.0 kullanıyordu) toplamda ~+6-10 dB algısal yükseklik
  # veriyordu; en sondaki limiter de bunun kırpılmadan tavana yaslanmasını
  # sağlıyordu.
  #
  # Buradaki zincir aynı işi EasyEffects uygulaması OLMADAN yapıyor: filter-chain
  # pipewire daemon'ının kendi içinde çalışır, ayrı bir GTK/DBus servisi yok.
  # Idle bütçesi (4.28 W) etkilenmez — düğüm hiçbir akış yokken pipewire
  # tarafından askıya alınır, DSP yalnızca ses çalarken CPU harcar.
  #
  # ZİNCİR:  high-pass 90Hz → bas +5dB@130 → presence +2.5dB@3k → LSP limiter
  # Yüksekliği veren asıl kademe LIMITER'in "Input gain" portu: sinyali
  # eşiğin içine iterek ortalama seviyeyi yükseltiyor, tepe kırpılmasını da
  # limiter'in kendisi engelliyor. AYAR DÜĞMESİ ODUR (aşağıda işaretli).
  #
  # KULAKLIK ETKİLENMEZ: hedef, UCM'in ayrı Speaker sink'i
  # (alsa_output.pci-0000_65_00.6.HiFi__Speaker__sink). Kulaklık takılınca
  # WirePlumber ayrı bir Headphone sink'i açar, bu zincir oraya bağlanmaz.
  # EasyEffects'in aksine bu bir iyileşme: o preset her çıkışa uygulanıyordu.
  # ------------------------------------------------------------------------
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
                  # Port adları ve aralıkları eklentinin LADSPA descriptor'ından
                  # okunarak doğrulandı (swh-plugins 0.4.17, 28 Ağu 2026) —
                  # tahmin değil. Üç kontrol portu var, üçü de doğrudan
                  # dB/saniye cinsinden (LSP'nin lineer "(G)" portlarının aksine).
                  control = {
                    # >>> SESİ AÇAN/KISAN DÜĞME BU (aralık -20 .. +20 dB).
                    # Sinyali limiter eşiğinin içine iter: tepe noktaları
                    # bastırılırken altındaki her şey yukarı çıkar, algısal
                    # yükseklik buradan gelir. Az geliyorsa 7-8'e çık; 808'lerde
                    # eziklik ya da pompalama duyarsan geri in.
                    "Input gain (dB)"  = 5.0;

                    # Tavan. Tam 0 dBFS yerine bir tık altı: örnekler-arası
                    # tepeler (inter-sample peak) DAC'ta kırpmasın.
                    "Limit (dB)"       = -1.0;

                    # Kazancın geri toplanma süresi (aralık 0.01 .. 2 s).
                    # EasyEffects 8 ms kullanıyordu, ama orada asıl yükü
                    # multiband kompresör taşıyordu; burada limiter tek başına
                    # çalıştığı için o kadar hızlı release bas frekanslarında
                    # bozulma üretir. 50 ms dengeli başlangıç.
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

            # Uygulamaların gördüğü sanal sink.
            "capture.props" = {
              "node.name"        = "effect_input.hoparlor";
              "media.class"      = "Audio/Sink";
              "audio.channels"   = 2;
              "audio.position"   = [ "FL" "FR" ];
              # Gerçek hoparlör sink'i 1000'de (wpctl inspect ile ölçüldü);
              # 2000 vererek WirePlumber'ın bunu KENDİLİĞİNDEN varsayılan
              # seçmesini sağlıyoruz — `wpctl set-default` ile mutable state'e
              # yazmak yerine bildirimsel kalsın diye.
              "priority.session" = 2000;
            };

            # Zincirin çıkışı. target.object ŞART: verilmezse çıkış akışı
            # varsayılan sink'i arar, o da artık bu zincirin kendisi olduğu için
            # graf kendine bağlanır. node.passive = akış yokken bağlantı grafı
            # ayakta tutmaz (idle'da askıya alınabilsin diye).
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
