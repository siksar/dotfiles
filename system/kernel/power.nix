{ config, pkgs, inputs, ... }:

{
  services.power-profiles-daemon.enable = true;

  services.printing.enable = false;

  # CachyOS bore-lto-zen4: -march=znver4 → başka CPU'da boot etmez.
  # pkgs.linuxPackagesFor KASITLI: nvidia/acpi_call/aero_eg61h bizim pin'imizde kalır ve her
  # çekirdek/sürücü bump'ında yerel derlenir (~15-25 dk).
  boot.kernelPackages =
    pkgs.linuxPackagesFor inputs.cachyos-kernel.packages.${pkgs.stdenv.hostPlatform.system}.linux-cachyos-bore-lto-zen4;

  nix.settings = {
    substituters       = [ "https://attic.xuyh0120.win/lantian" ];
    trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
  };

  boot.initrd.kernelModules = [ "amdgpu" ];

  boot.blacklistedKernelModules = [ "amdxdna" ];

  boot.consoleLogLevel = 0;
  boot.initrd.verbose  = false;

  boot.kernelParams = [
    # Güvenlik azaltmaları KAPALI (kullanıcı kararı, ~%3-7 kazanç).
    "mitigations=off"

    "amd_pstate=active"
    # amdgpu.gfx_off diye parametre yok (kernel reddeder).
    "amdgpu.abmlevel=4"

    # zswap kapalı: zram ile çift sıkıştırma olmasın.
    "zswap.enabled=0"

    # lazy RCU: CachyOS kapalı getiriyor (+0.88 W boşta); yalnız boot parametresi.
    "rcutree.enable_rcu_lazy=1"

    "nowatchdog"  # soft + NMI watchdog ikisi de kapalı (nmi_watchdog=0 alt kümesiydi)
    "pcie_aspm=force"
    "pcie_aspm.policy=powersupersave"
    "pcie_port_pm=force"
    "workqueue.power_efficient=1"
    "mem_sleep_default=s2idle"
    "nohibernate"  # hibernate kapalı: aşağıdaki not

    "quiet"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "boot.shell_on_fail"
  ];

  # HDA power_save'in tek tanımı burası (cmdline'da kopyası yok).
  boot.extraModprobeConfig = ''
    options rtw89_pci disable_clkreq=0 disable_aspm_l1=0 disable_aspm_l1ss=0
    options rtw89_core disable_ps_mode=n
    options snd_hda_intel power_save=1 power_save_controller=Y
  '';

  # powertop --auto-tune dirty_writeback'i ezer (sysctl'den sonra koşar) → değeri aşağıdaki
  # power-tunables-restore da yazar; değiştirirsen ikisini birden.
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000;
    "vm.dirty_expire_centisecs"   = 6000;
  };

  # commit=60: jbd2 her 5 s NVMe'yi uyandırıyordu. lazytime + noatime.
  fileSystems."/".options = [ "noatime" "lazytime" "commit=60" ];

  powerManagement.powertop.enable = true;

  # Girdi cihazları autosuspend'den muaf: powertop dahili klavyeyi askıya alıyordu (tuş gecikmesi).
  # Boot'ta powertop sonra koştuğu için power-tunables-restore şart. /proc/acpi/wakeup TOGGLE'dır, kullanma.
  services.udev.extraRules = ''
    # power/control="on"      : autosuspend kapalı (yukarıdaki girdi-gecikmesi gerekçesi)
    # power/wakeup="disabled" : uykudayken sistemi uyandıramasın (yukarıdaki politika)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0414", ATTR{idProduct}=="8104", ATTR{power/control}="on", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="258a", ATTR{idProduct}=="0049", ATTR{power/control}="on", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="22d4", ATTR{idProduct}=="1503", ATTR{power/control}="on"
  '';

  # After=powertop.service; graphical.target (multi-user → sıralama döngüsü).
  systemd.services.power-tunables-restore = {
    description = "powertop --auto-tune'un ezdiği ayarları geri yaz";
    wantedBy = [ "graphical.target" ];
    after    = [ "powertop.service" ];
    wants    = [ "powertop.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "power-tunables-restore" ''
        # 1) writeback gecikmesi — boot.kernel.sysctl'deki değerle EŞ tutulmalı
        echo 6000 > /proc/sys/vm/dirty_writeback_centisecs

        # 2) girdi cihazları: autosuspend kapalı; iki klavyede uyandırma kapalı (powertop ezebilir diye burada da).
        for D in /sys/bus/usb/devices/*/; do
          V=$(cat "$D/idVendor" 2>/dev/null) || continue
          P=$(cat "$D/idProduct" 2>/dev/null) || continue
          case "$V:$P" in
            0414:8104|258a:0049|22d4:1503)
              echo on > "$D/power/control" 2>/dev/null || true
              ;;
          esac
          case "$V:$P" in
            0414:8104|258a:0049)
              echo disabled > "$D/power/wakeup" 2>/dev/null || true
              ;;
          esac
        done
      '';
    };
  };

  # resumeDevice olmadan systemd-stage-1 resume= eklemez. Hibernate nohibernate ile kapalı.
  boot.resumeDevice = (builtins.head config.swapDevices).device;

  # Hibernate KAPALI: freeze amdgpu TTM'yi bozuyor → oyunda tam kilitlenme.

  systemd.sleep.settings.Sleep = {
    HibernateDelaySec  = "25min";
    HibernateOnACPower = true;
  };

  # Kapak / suspend tuşu düz s2idle (mem_sleep'te deep yok).
  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleSuspendKey             = "suspend";
  };
}
