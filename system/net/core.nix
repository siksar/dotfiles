{ pkgs, ... }:

let
  # Kablo takılıyken (eno1 carrier=1) WiFi kapanır. wlan0 olayları yok sayılır (churn).
  ethWifiArbiter = pkgs.writeShellScript "eth-wifi-arbiter" ''
    IFACE="''${1:-}"
    [ -n "$IFACE" ] && [ -d "/sys/class/net/$IFACE/wireless" ] && exit 0
    [ "$IFACE" = "lo" ] && exit 0

    CARRIER=$(${pkgs.coreutils}/bin/cat /sys/class/net/eno1/carrier 2>/dev/null || echo 0)
    if [ "$CARRIER" = "1" ]; then
      ${pkgs.networkmanager}/bin/nmcli radio wifi off 2>/dev/null || true
    else
      ${pkgs.networkmanager}/bin/nmcli radio wifi on 2>/dev/null || true
    fi
  '';
in
{
  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";

    dns = "systemd-resolved";

    dispatcherScripts = [
      { source = ethWifiArbiter; type = "basic"; }
    ];
  };
  networking.modemmanager.enable = false;

  boot.extraModprobeConfig = ''
    options cfg80211 ieee80211_regdom=TR
  '';

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "false";
      DNSOverTLS = "false";
    };
  };

  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.core.default_qdisc"          = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fastopen"           = 3;
  };

  # Boot senkronu: kablolu kapatılan WiFi NM'de kalıcı; kablosuz boot'ta eno1 olayı gelmez.
  systemd.services.eth-wifi-arbiter = {
    description = "Kablo takılıysa WiFi'ı kapat (boot ilk senkronu)";
    wantedBy = [ "multi-user.target" ];
    after    = [ "NetworkManager.service" ];
    wants    = [ "NetworkManager.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = ethWifiArbiter;
    };
  };

  # iwd ↔ rtw89 açılış yarışı: iwd wlan0 kaydolmadan phy0'ı görürse arayüzü kendisi yaratıp düşüyor.
  systemd.services.iwd = {
    after = [ "sys-subsystem-net-devices-wlan0.device" ];
    wants = [ "sys-subsystem-net-devices-wlan0.device" ];
  };

  # Kapalı: graphical.target'ı ~49 s kilitliyordu.
  systemd.services.NetworkManager-wait-online.enable = false;
}
