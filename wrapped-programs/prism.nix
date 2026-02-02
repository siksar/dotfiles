{ pkgs, lib, ... }:

let
  # Sarmalanmış paketi tanımlıyoruz
  prism-nvidia = pkgs.symlinkJoin {
    name = "prism-launcher-nvidia";
    paths = [ pkgs.prismlauncher ]; # Orijinal paketin tüm içeriğini al (ikonlar dahil)
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      # HATA ÇÖZÜMÜ:
      # Orijinal dosya bir 'symlink' (kısayol) olduğu için düzenlenemez.
      # Bu yüzden önce o kısayolu siliyoruz.
      rm "$out/bin/prism-launcher"

      # Şimdi 'makeWrapper' ile sıfırdan yeni bir çalıştırılabilir dosya oluşturuyoruz.
      # Bu dosya, arka planda orijinal Prism Launcher'ı NVIDIA ayarlarıyla çağıracak.
      makeWrapper "${pkgs.prismlauncher}/bin/prism-launcher" "$out/bin/prism-launcher" \
        --set __NV_PRIME_RENDER_OFFLOAD 1 \
        --set __NV_PRIME_RENDER_OFFLOAD_PROVIDER NVIDIA-G0 \
        --set __GLX_VENDOR_LIBRARY_NAME nvidia \
        --set __VK_LAYER_NV_optimus NVIDIA_only
    '';
  };
in
{
  # lib.hiPrio kullanarak, sistemde başka bir Prism Launcher olsa bile
  # senin bu özel ayarlı paketinin "baskın" gelmesini sağlıyoruz.
  environment.systemPackages = [ 
    (lib.hiPrio prism-nvidia)
  ];
}
