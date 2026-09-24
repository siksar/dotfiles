# GitHub Copilot desktop uygulaması — kullanıcı tarafından indirilen resmî AppImage.
#
# Uygulamanın kendi güncelleyicisi AppImage dosyasını YERİNDE değiştirir. Bu yüzden
# dosyayı wrapType2 ile Nix store'a kopyalamıyoruz: store salt-okunur olduğundan o
# yol güncelleyiciyi engeller. Başlatıcı her açılışta Downloads'taki aynı dosyayı
# appimage-run ile çalıştırır; GitHub güncelledikten sonra rebuild gerekmez.
{ pkgs, ... }:

let
  githubCopilot = pkgs.writeShellApplication {
    name = "github-copilot";
    runtimeInputs = [ pkgs.appimage-run ];
    text = ''
      appimage=/home/zixar/Downloads/GitHub-Copilot-linux-x64.AppImage

      if [ ! -f "$appimage" ]; then
        echo "GitHub Copilot AppImage bulunamadı: $appimage" >&2
        exit 1
      fi

      # İndirilen dosya executable biti olmadan gelmiş olabilir. GitHub'ın
      # güncelleyicisinin yerinde yazdığı yeni dosya için de bunu garantiler.
      chmod u+x "$appimage"
      exec appimage-run "$appimage" "$@"
    '';
  };
  desktopItem = pkgs.makeDesktopItem {
    name = "github-copilot";
    desktopName = "GitHub Copilot";
    comment = "GitHub Copilot desktop application";
    exec = "github-copilot %U";
    categories = [ "Development" "IDE" ];
    startupWMClass = "github";
  };
in {
  programs.appimage.enable = true;

  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "github-copilot";
      paths = [ githubCopilot desktopItem ];
      meta = {
        description = "GitHub Copilot desktop application";
        mainProgram = "github-copilot";
        platforms = [ "x86_64-linux" ];
      };
    })
  ];
}
