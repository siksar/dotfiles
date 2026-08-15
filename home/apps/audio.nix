# Hoparlör ekolayzeri (HM) — EasyEffects, PipeWire filtre zinciri üzerinde.
#
# Dolby Atmos Windows'a özel kapalı kaynak bir sürücü/APO zinciridir (Dolby
# Access uygulaması + üretici imzalı codec sürücüsü) — Linux'a resmi ya da
# tersine mühendislik yoluyla taşınmış bir sürümü yok, bu yüzden burada
# "Atmos'u aç" diye bir seçenek YOK. Windows'ta Atmos'un asıl yaptığı iş
# zaten 2 hoparlörlü bir laptopta objektif ses değil; parametrik EQ + dinamik
# bas artırma + limiter (kırpılmayı önleyen tavan) — EasyEffects'in LSP
# eklentileriyle yaptığı da tam olarak bu. `wpctl status` çıktısı bu
# makinede ALC245 kodekinin AMD HDA veri yolu üzerinden çıplak (SOF/akıllı
# amfi DSP'si yok) çaldığını gösterdi — yani şu an hoparlörlere giden sinyal
# TAMAMEN işlenmemiş; "bozuk" hissi muhtemelen bunun sonucu.
#
# `preset` sebastian-de/easyeffects-thinkpad-unsuck (MIT) + M0Rf30/easyeffects-presets
# "Tiny Speaker Rescue" (MIT) karışımı, kullanıcının müzik zevkine (Yeat, Frank
# Ocean, Drake — ağır 808 sub-bas + vokal-öncelikli miks + parlak hi-hat) göre
# ayarlandı:
#   filter (100Hz high-pass) → sürücünün gerçekten çıkaramadığı rumble'ı keser
#     ama 808'in temelini (genelde ~40-80Hz) mümkün olduğunca bırakır — 140Hz'de
#     bu tür trap/hip-hop prodüksiyonun basının çoğu gidiyordu
#   bass_enhancer  → kesilen altı harmonikle algısal olarak geri veriyor; 808
#     ağırlığı hissi için amount/harmonics yüksek tutuldu
#   crystalizer    → tiz bantlarda hafif "keskinlik" — Frank Ocean/Drake'in
#     vokal netliği ve Yeat'in hi-hat/adlib parlaklığı için (Tiny Speaker
#     Rescue'dan aynen alındı, kanıtlanmış değerler)
#   multiband_compressor → bant başına dinamik denge, 808'lerin tutarlı/punchy
#     kalmasını sağlıyor
#   stereo_tools   → hafif stereo genişletme (Atmos'un "geniş" hissinin taklidi)
#   limiter (en sonda) → tepe kırpılmasını önler, yüksek seste "bozulma" burada durur
# JSON şeması EasyEffects 8.x'e uyduğu doğrulandı (nixpkgs'teki paket 8.2.8).
# Bu hâlâ bir başlangıç noktası — dinleyip GUI'den ince ayar yap, sonra buraya geri yaz.
{ ... }:

{
  services.easyeffects = {
    enable = true;
    preset = "hoparlor";

    extraPresets.hoparlor.output = {
      "filter#0" = {
        balance     = 0.0;
        bypass      = false;
        equal-mode  = "IIR";
        frequency   = 100.0; # 140'tı — trap/hip-hop 808'in temeli çoğunlukla 40-80Hz'de,
        gain        = 0.0;   # 140Hz'de o 808'in büyük kısmı zaten kesiliyordu
        input-gain  = 0.0;
        mode        = "RLC (BT)";
        output-gain = 0.0;
        quality     = 0.0;
        slope       = "x3";
        type        = "High-pass";
        width       = 4.0;
      };

      "bass_enhancer#0" = {
        amount       = 26.0; # 22'ydi — 808 ağırlığı için biraz daha algısal bas
        blend        = 0.0;
        bypass       = false;
        floor        = 10.0;
        floor-active = true;
        harmonics    = 12.0; # 10'du
        input-gain   = 0.0; # kaynak -6.0'dı (ThinkPad daha yüksek çalıyordu) —
        output-gain  = 0.0; # bizim hoparlörde bu tek başına "kısık" hissinin sebebiydi
        scope        = 200.0;
      };

      # Tiny Speaker Rescue'dan (M0Rf30/easyeffects-presets, MIT) aynen alındı —
      # hafif tiz "keskinlik": vokal netliği + hi-hat/adlib parlaklığı, aşırıya
      # kaçmadan (band2 hafif kısılmış, sert/tiz gelmesin diye).
      "crystalizer#0" = {
        adaptive-intensity = true;
        bypass             = false;
        fixed-quantum      = false;
        input-gain         = 0.0;
        output-gain        = 0.0;
        oversampling       = true;
        oversampling-quality = 5.0;
        transition-band    = 120.0;

        band0  = { bypass = false; intensity = 2.0;  mute = false; };
        band1  = { bypass = false; intensity = 1.0;  mute = false; };
        band2  = { bypass = false; intensity = -2.0; mute = false; };
        band3  = { bypass = false; intensity = 0.0;  mute = false; };
        band4  = { bypass = false; intensity = 0.0;  mute = false; };
        band5  = { bypass = false; intensity = 0.0;  mute = false; };
        band6  = { bypass = false; intensity = 0.0;  mute = false; };
        band7  = { bypass = false; intensity = 0.0;  mute = false; };
        band8  = { bypass = false; intensity = 0.0;  mute = false; };
        band9  = { bypass = false; intensity = 0.0;  mute = false; };
        band10 = { bypass = false; intensity = 0.0;  mute = false; };
        band11 = { bypass = false; intensity = 0.0;  mute = false; };
        band12 = { bypass = false; intensity = 0.0;  mute = false; };
      };

      "multiband_compressor#0" = {
        bypass           = false;
        compressor-mode  = "Modern";
        dry              = -80.01;
        envelope-boost   = "None";
        input-gain       = 0.0;
        input-to-link    = 0.0;
        input-to-sidechain = 0.0;
        link-to-input    = 0.0;
        link-to-sidechain = 0.0;
        output-gain      = 0.0;
        sidechain-to-input = 0.0;
        sidechain-to-link  = 0.0;
        stereo-split     = false;
        wet              = 0.0;

        band0 = {
          attack-threshold  = -16.0;
          attack-time       = 150.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          knee              = -12.0;
          makeup            = 4.0;
          mute              = false;
          ratio             = 5.0;
          release-threshold = -80.01;
          release-time      = 300.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 500.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 10.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          stereo-split-source = "Left/Right";
        };

        band1 = {
          attack-threshold  = -24.0;
          attack-time       = 150.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          enable-band       = true;
          knee              = -9.0;
          makeup            = 3.0;
          mute              = false;
          ratio             = 3.0;
          release-threshold = -80.01;
          release-time      = 200.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 1000.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 500.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          split-frequency    = 250.0;
          stereo-split-source = "Left/Right";
        };

        band2 = {
          attack-threshold  = -24.0;
          attack-time       = 100.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          enable-band       = true;
          knee              = -9.0;
          makeup            = 3.0;
          mute              = false;
          ratio             = 3.0;
          release-threshold = -80.01;
          release-time      = 150.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 2000.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 1000.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          split-frequency    = 1250.0;
          stereo-split-source = "Left/Right";
        };

        band3 = {
          attack-threshold  = -24.0;
          attack-time       = 80.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          enable-band       = true;
          knee              = -9.0;
          makeup            = 4.0;
          mute              = false;
          ratio             = 4.0;
          release-threshold = -80.01;
          release-time      = 120.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 4000.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 2000.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          split-frequency    = 5000.0;
          stereo-split-source = "Left/Right";
        };

        band4 = {
          attack-threshold  = -12.0;
          attack-time       = 20.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          enable-band       = false;
          knee              = -6.0;
          makeup            = 0.0;
          mute              = false;
          ratio             = 1.0;
          release-threshold = -80.01;
          release-time      = 100.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 8000.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 4000.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          split-frequency    = 4000.0;
          stereo-split-source = "Left/Right";
        };

        band5 = {
          attack-threshold  = -12.0;
          attack-time       = 20.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          enable-band       = false;
          knee              = -6.0;
          makeup            = 0.0;
          mute              = false;
          ratio             = 1.0;
          release-threshold = -80.01;
          release-time      = 100.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 12000.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 8000.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          split-frequency    = 8000.0;
          stereo-split-source = "Left/Right";
        };

        band6 = {
          attack-threshold  = -12.0;
          attack-time       = 20.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          enable-band       = false;
          knee              = -6.0;
          makeup            = 0.0;
          mute              = false;
          ratio             = 1.0;
          release-threshold = -80.01;
          release-time      = 100.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 16000.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 12000.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          split-frequency    = 12000.0;
          stereo-split-source = "Left/Right";
        };

        band7 = {
          attack-threshold  = -12.0;
          attack-time       = 20.0;
          boost-amount      = 6.0;
          boost-threshold   = -72.0;
          compression-mode  = "Downward";
          compressor-enable = true;
          enable-band       = false;
          knee              = -6.0;
          makeup            = 0.0;
          mute              = false;
          ratio             = 1.0;
          release-threshold = -80.01;
          release-time      = 100.0;
          sidechain-custom-highcut-filter = false;
          sidechain-custom-lowcut-filter  = false;
          sidechain-highcut-frequency = 20000.0;
          sidechain-lookahead = 0.0;
          sidechain-lowcut-frequency  = 16000.0;
          sidechain-mode    = "RMS";
          sidechain-preamp  = 0.0;
          sidechain-reactivity = 10.0;
          sidechain-source  = "Middle";
          sidechain-type    = "Internal";
          solo              = false;
          split-frequency    = 16000.0;
          stereo-split-source = "Left/Right";
        };
      };

      "stereo_tools#0" = {
        balance-in    = 0.0;
        balance-out   = 0.0;
        bypass        = false;
        delay         = 0.0;
        dry           = -100.0;
        input-gain    = 0.0;
        middle-level  = 0.0;
        middle-panorama = 0.0;
        mode          = "LR > LR (Stereo Default)";
        mutel         = false;
        muter         = false;
        output-gain   = 0.0;
        phasel        = false;
        phaser        = false;
        sc-level      = 1.0;
        side-balance  = 0.0;
        side-level    = 0.0;
        softclip      = false;
        stereo-base   = 0.30000000000000004;
        stereo-phase  = 0.0;
        wet           = 0.0;
      };

      "limiter#0" = {
        alr                 = false;
        alr-attack          = 5.0;
        alr-knee            = 0.0;
        alr-release         = 50.0;
        attack              = 2.0;
        bypass              = false;
        dithering           = "None";
        gain-boost          = false;
        input-gain          = 0.0;
        input-to-link       = 0.0;
        input-to-sidechain  = 0.0;
        link-to-input       = 0.0;
        link-to-sidechain   = 0.0;
        lookahead           = 4.000000000000021;
        mode                = "Herm Thin";
        output-gain         = 0.0;
        oversampling        = "Half x4/24 bit";
        release             = 8.0;
        sidechain-preamp    = 0.0;
        sidechain-to-input  = 0.0;
        sidechain-to-link   = 0.0;
        sidechain-type      = "Internal";
        stereo-link         = 100.0;
        threshold           = 0.0;
      };

      blocklist = [ ];

      plugins_order = [
        "filter#0"
        "bass_enhancer#0"
        "crystalizer#0"
        "multiband_compressor#0"
        "stereo_tools#0"
        "limiter#0"
      ];
    };
  };
}
