# OpenCode + NVIDIA NIM. API anahtarı secrets/opencode.env'de (store'a sır yazma).
# Model listesi burada TUTULMAZ: plugins/nvidia-nim-catalog.js canlı NIM listesine keser;
# config override'ları kancadan sonra uygulanır, `models` eklemek zinciri bozar.
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
      # Seçenekler: opencode models | grep '^nvidia/'
      model = "nvidia/nvidia/nemotron-3-super-120b-a12b";
    };

    # Dizin adı ÇOĞUL (plugins/); tekil plugin/ yüklenmiyor.
    "opencode/plugins/nvidia-nim-catalog.js".text = builtins.readFile ./opencode-nim-catalog.js;
  };

  # if-formu bilinçli: hm-setup-env `bash -el`, &&-zinciri düşerse aktivasyon ölür.
  programs.bash.profileExtra = ''
    if [ -f /etc/nixos/secrets/opencode.env ]; then
      set -a
      source /etc/nixos/secrets/opencode.env
      set +a
    fi
  '';
}
