{ ... }:

{
  # zram 16 GB öncelik 5 > disk swap; zswap kapalı (power.nix) — çift sıkıştırma olmasın.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  boot.kernel.sysctl = {
    "vm.swappiness"   = 180;
    "vm.page-cluster" = 0;
  };

  # oomd: kullanıcı dilimlerinde 30 s %80 PSI → en çok baskı yapanı öldür. Kök/sistem dilimi kapalı.
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
  };

  # /tmp tmpfs, boot.tmp.useTmpfs YERİNE elle: canlı switch yeni mount'u dolu /tmp'nin üstüne
  # bindirip X11/tmux soketlerini gizliyordu. ConditionPathExists=!/run/user/1000 → yalnız açılışta bağlanır.
  systemd.mounts = [
    {
      what = "tmpfs";
      where = "/tmp";
      type = "tmpfs";
      mountConfig.Options = "mode=1777,strictatime,rw,nosuid,nodev,size=50%,huge=never";
      unitConfig.ConditionPathExists = "!/run/user/1000";
      wantedBy = [ "local-fs.target" ];
    }
  ];
}
