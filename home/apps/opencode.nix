# OpenCode — terminal AI coding agent (paket: configuration.nix systemPackages'ta
# environment.systemPackages, "LLM-assisted development" altında).
# Sağlayıcı: NVIDIA NIM (OpenAI-uyumlu, https://integrate.api.nvidia.com/v1).
#
# API anahtarı bu dosyaya YAZILMAZ — nix store dünyaya açık okunabilir
# olduğundan sır burada değil, repo dışı sayılan (.gitignore: secrets/)
# secrets/opencode.env içinde tutulur ve shell login'de source edilir.
# opencode.json içindeki {env:NVIDIA_API_KEY} bunu runtime'da okur.
# /etc/nixos üzerinden okunuyor bilerek: /home/zixar/nixos-zixar'a taşındıktan
# sonra da /etc/nixos kalıcı bir compat symlink olarak kalacağından bu yol her
# iki durumda da (taşımadan önce/sonra) doğru dosyayı gösterir.
#
# MODEL LİSTESİ BURADA TUTULMAZ. Elle sabitlenen dört model 17 Eyl 2026'da
# ölçüldüğünde dördü de NIM'de ölüydü (qwen3-coder-480b çağrısı HTTP 410
# "end of life on 2026-06-11" döndürdü) — sabit liste sessizce eskiyor.
# Katalog artık iki katmandan geliyor:
#   1. models.dev — opencode'un kendi indirdiği metadata (limit, maliyet,
#      tool_call/reasoning yetenekleri). NIM'i geriden takip eder.
#   2. plugins/nvidia-nim-catalog.js — her açılışta NIM'in /v1/models'ını
#      okuyup listeyi canlı gerçeğe kesen kanca (aşağıda).
# Buraya bir `models` bloğu eklemek bu zinciri BOZAR: config override'ları
# kancadan SONRA uygulanır, yani ölü bir model burada yaşamaya devam eder.
{ ... }:

{
  xdg.configFile = {
    "opencode/opencode.json".text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      provider.nvidia = {
        npm = "@ai-sdk/openai-compatible";
        name = "NVIDIA NIM";
        options = {
          baseURL = "https://integrate.api.nvidia.com/v1";
          apiKey = "{env:NVIDIA_API_KEY}";
        };
      };
      # Eski öntanımlı (qwen3-coder-480b) 11 Haz 2026'da EOL oldu, çağrısı
      # HTTP 410 döndürüyor. Yerine geçen 17 Eyl 2026'da ÖLÇÜLEREK seçildi:
      # araç tanımı gönderilen /chat/completions çağrısına 1,1 s'de 200 + "PONG".
      # Aynı turda kimi-k3, glm-5.3, glm-5.3-flash ve deepseek-v4-flash 60-120 s
      # içinde hiç yanıt vermedi (ücretsiz katmanda kuyruk), kimi-k2.6 ise
      # /v1/models'da görünmesine rağmen 404 — yani canlı liste "çağrılabilir"in
      # üst sınırı, garantisi değil. Model değiştirmek bu tek satırlık iş;
      # seçenekleri `opencode models | grep '^nvidia/'` listeler.
      model = "nvidia/nvidia/nemotron-3-super-120b-a12b";
    };

    # Dizin adı ÇOĞUL. opencode 1.18.29 yalnız ~/.config/opencode/plugins/
    # altını tarar; belgelerin bir yerinde geçen tekil "plugin/" yüklenmiyor.
    # 17 Eyl 2026'da ölçüldü: tekil dizinde `opencode models` 103 nvidia modeli
    # sayıyor (yani kanca hiç koşmamış), çoğulda 62 (canlı NIM listesi).
    # `.text = readFile` bilinçli: içerik eval anında gömülür, store kopyası
    # olmadığı için kaynak dosya serbestçe yeniden adlandırılabilir
    # (CLAUDE.md sert kural 2 — `${./x}` olsaydı ad kilitlenirdi).
    "opencode/plugins/nvidia-nim-catalog.js".text = builtins.readFile ./opencode-nim-catalog.js;
  };

  # secrets/opencode.env yoksa (ör. taze clone) sessizce atlanır.
  # if-formu bilinçli: hm-setup-env login'i `bash -el` (errexit) açar,
  # &&-zincirinin son komutu düşerse aktivasyonu öldürür.
  programs.bash.profileExtra = ''
    if [ -f /etc/nixos/secrets/opencode.env ]; then
      set -a
      source /etc/nixos/secrets/opencode.env
      set +a
    fi
  '';
}
