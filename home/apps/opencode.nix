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
{ ... }:

{
  xdg.configFile."opencode/opencode.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    provider = {
      nvidia = {
        npm = "@ai-sdk/openai-compatible";
        name = "NVIDIA NIM";
        options = {
          baseURL = "https://integrate.api.nvidia.com/v1";
          apiKey = "{env:NVIDIA_API_KEY}";
        };
        models = {
          "qwen/qwen3-coder-480b-a35b-instruct" = {
            name = "Qwen3 Coder 480B A35B (NIM)";
            tool_call = true;
            limit = {
              context = 256000;
              output = 32768;
            };
          };
          "qwen/qwen3.5-397b-a17b" = {
            name = "Qwen3.5 397B A17B (NIM)";
            reasoning = true;
            tool_call = true;
            limit = {
              context = 262144;
              output = 8192;
            };
          };
          "minimaxai/minimax-m3" = {
            name = "MiniMax M3 (NIM)";
            reasoning = true;
            tool_call = true;
            limit = {
              context = 1000000;
              output = 16384;
            };
          };
          "z-ai/glm-5.2" = {
            name = "GLM-5.2 (NIM)";
            reasoning = true;
            tool_call = true;
            limit = {
              context = 1000000;
              output = 131072;
            };
          };
        };
      };
    };
    model = "nvidia/qwen/qwen3-coder-480b-a35b-instruct";
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
