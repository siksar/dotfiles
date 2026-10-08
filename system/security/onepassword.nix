{ ... }:

{
  # polkitPolicyOwners boşsa sistem-auth kilidi ve tarayıcı köprüsü izin hatası verir.
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "zixar" ];
  };

  # `op` setgid sarmalayıcı olarak kurulur; düz paketi systemPackages'a atmak GUI eşleşmesini kırar.
  programs._1password.enable = true;

  # 1Password-BrowserSupport süreç adını sabit listeyle karşılaştırır; Zen yok → listeye ekle.
  environment.etc."1password/custom_allowed_browsers" = {
    text = ''
      zen
      zen-beta
      .zen-beta-wrapped
    '';
    mode = "0755";
  };
}
