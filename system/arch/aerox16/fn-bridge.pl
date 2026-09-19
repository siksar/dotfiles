#!/usr/bin/env perl
# fn-bridge.pl — dahili klavyenin SATICI 0xFF02 raporlarını gerçek tuşa çevirir.
#
# Neden: Fn+F4 (mikrofon), Fn+F7 (performans/fan), Fn+F9 (touchpad) bu makinede
# yalnız satıcı sayfası 0xFF02 / Report ID 4 üzerinden geliyor; Linux o raporu
# evdev'e HİÇ çevirmediği için üç tuş da işlevsiz. Ölçüm ve kodlar:
# Documentation/aerox16/fn-keys.md.
#
# İKİ MOD, çünkü tek başına tuş üretmek bu masaüstünde yetmiyor:
#   (varsayılan) POLİTİKA YOK — yalnız evdev tuşu üretir. Doğru katman budur:
#     kısayolun sahibi masaüstü olmalı, köprü değil.
#   --act        Tuşa ek olarak eylemi de yapar. Gerekçe ÖLÇÜM: COSMIC bu üç
#     tuşa (KEY_MICMUTE / KEY_PROG1 / KEY_TOUCHPAD_TOGGLE) hiçbir eylem
#     bağlamıyor, yani saf tuş modunda üç Fn tuşu hâlâ ölü kalıyor
#     (16 Eyl 2026, fn-keys.md). COSMIC tarafında kısayol tanımlanırsa bu mod
#     gereksizleşir — o gün SİL.
#
# Kullanım:  fn-bridge [--act] [--debug] [--user <ad>]      (root ister)
#            Sistemde `aero-fn-bridge.service` bunu --act ile koşturur;
#            elle denemek için servisi durdur, sonra kendin çalıştır.
use strict;
use warnings;

$| = 1;

my $DEBUG   = grep { $_ eq '--debug' } @ARGV;
my $ACT     = grep { $_ eq '--act'   } @ARGV;
my $DEBOUNCE = 0.25;   # s — Fn+F9 tek basışta iki özdeş rapor gönderiyor
# Kullanıcı adı: mikrofon eylemi ses sunucusuna, o da kullanıcı oturumuna ait.
# --user ile açıkça verilir (systemd birimi böyle çağırır); elle çalıştırmada
# sudo'nun SUDO_USER'ı yeter.
my ($UIDX) = grep { $ARGV[$_] eq '--user' } 0..$#ARGV;
my $USER = defined $UIDX ? $ARGV[$UIDX + 1] : ($ENV{SUDO_USER} // 'zixar');

# 0xFF02 kodu → evdev tuşu + (--act için) eylem. Kodlar fn-probe.pl ölçümünden
# (16 Eyl 2026). Eylem alanı bir alt program: yalnız --act ile çağrılır.
# Beşinci alan: "GNOME bu tuşu kendisi işler mi?" — işliyorsa o oturumda eylemi
# biz yapmayız (çift toggle olur). KEY_PROG1'i hiçbir masaüstü işlemiyor.
my %MAP = (
	0x92 => [248, 'KEY_MICMUTE',         'Fn+F4 mikrofon',             \&act_mic,      1],
	0x84 => [148, 'KEY_PROG1',           'Fn+F7 performans/fan modu',  \&act_fan,      0],
	0x81 => [530, 'KEY_TOUCHPAD_TOGGLE', 'Fn+F9 touchpad kilidi',      \&act_touchpad, 1],
	# Fn+Esc — 19 Eyl 2026 ölçümü. Ham veri "04 00 01 95": ÜÇÜNCÜ bayt 0x01,
	# bilinen üçlüde 0x00'dı — muhtemelen kilidin yeni durumunu taşıyor, ama
	# ikinci basış ölçülmediği için doğrulanmadı. Eylem YOK: Fn kilidi klavye
	# denetleyicisinin kendi içinde uygulanıyor, bizim yapacağımız bir şey yok;
	# tuşu yine de üretiyoruz, doğru katman orası.
	0x95 => [465, 'KEY_FN_ESC',          'Fn+Esc Fn kilidi',           sub { 'klavye kendi hallediyor' }, 0],
);

# İKİNCİ ALT-PROTOKOL — 19 Eyl 2026'da CANLI journal'dan bulundu.
# Klavye 0xFF02'de İKİ ayrı rapor biçimi gönderiyor ve İKİNCİ BAYT hangisi
# olduğunu söylüyor:
#     04 00 00 <kod>    tür 0 → kod 4. baytta   (yukarıdaki %MAP: Fn+F4/F7/F9)
#     04 01 <kod> 00    tür 1 → kod 3. baytta   (bu tablo)
# Köprü eskiden kodu KOŞULSUZ $b[3]'ten okuyordu; tür 1'in bütün raporları bu
# yüzden "0x00" diye loglandı, hiçbiri eşleşmedi ve kanalın varlığı iki ay
# görülmedi. Journal kanıtı (aero-fn-bridge.service, PID 867):
#     Eyl 19 16:29:47.011  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 20 00)
#     Eyl 19 16:29:47.315  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 00 00)
# ÖLÇÜLDÜ (19 Eyl 2026, scripts/isik-probe.pl): kod, Fn+Space'in döndürdüğü
# FİRMWARE AYDINLATMA KADEMESİDİR — tuş kimliği değil, yeni seviyenin kendisi.
# Ardışık iki basış 0x18 → 0x20 verdi (artan); journal'daki 0x00 ve 0x32 ile
# birlikte dört kademe çıkıyor:
#
#     0x00 kapalı   0x18 düşük   0x20 orta   0x32 yüksek   → ve başa döner
#
# Fn+Space firmware'de bu döngüyü yürütür ve her adımda yeni kademeyi bildirir.
# AutonomousMode=0 iken (yani biz renk yazdığımızda) firmware ışığa DOKUNAMAZ,
# ama raporu göndermeyi SÜRDÜRÜR — bu yüzden döngüyü burada yakalayıp kendi
# rengimizle uyguluyoruz. Kullanıcı tek tuşla hem aç/kapa hem parlaklık alır.
# Gerekçe ve ölçüm: Documentation/aerox16/fn-keys.md "tür 1 kanalı".
#
# Yüzde eşlemesi BİZİM seçimimiz: ham değerler (0/24/32/50) firmware'in iç
# ölçeği, yüzde değil. Üç kademeyi eşit aralıklı seçtik.
my %MAP1 = (
	0x00 => [228, 'KEY_KBDILLUMTOGGLE', 'Fn+Space aydınlatma: kapalı', sub { act_light(0)   }, 0],
	0x18 => [230, 'KEY_KBDILLUMUP',     'Fn+Space aydınlatma: düşük',  sub { act_light(33)  }, 0],
	0x20 => [230, 'KEY_KBDILLUMUP',     'Fn+Space aydınlatma: orta',   sub { act_light(66)  }, 0],
	0x32 => [230, 'KEY_KBDILLUMUP',     'Fn+Space aydınlatma: yüksek', sub { act_light(100) }, 0],
);

# Mikrofon: ses sunucusu KULLANICI oturumunda, köprü root'ta → oturuma in.
sub act_mic {
	my $env = "runuser -u $USER -- env XDG_RUNTIME_DIR=/run/user/" . (getpwnam($USER) // 1000);
	run("$env wpctl set-mute \@DEFAULT_AUDIO_SOURCE\@ toggle");
	my $st = `$env wpctl get-volume \@DEFAULT_AUDIO_SOURCE\@ 2>/dev/null`;
	chomp $st;
	return $st =~ /MUTED/ ? 'mikrofon KAPALI' : 'mikrofon açık';
}

# Fan: döngüyü zaten yapan birim var (12 Eyl'den beri tetikleyicisizdi).
sub act_fan {
	run('systemctl start aero-fan-cycle.service');
	my ($f) = glob '/sys/bus/wmi/devices/ABBC0F75-*/fan_mode';
	my $mode = $f ? slurp($f) : '?';
	return "fan modu: $mode";
}

# Aydınlatma: firmware'in Fn+Space döngüsünü BİZİM parlaklığımıza aynalar.
# kbd-rgb'nin /dev/hidraw9'a erişimi için runuser GEREKMİYOR — düğümün sahibi
# root ve köprü root koşuyor (uaccess ACL yalnız EK kullanıcı tanımlar, sahibin
# erişimini kısıtlamaz). Durum dosyasının doğru yere düşmesi ise
# fn-keys.nix'teki XDG_STATE_HOME sabitine bağlı; o olmasa root kendi
# /root/.local/state'ine yazar ve kullanıcının durumundan kopardı.
sub act_light {
	my $pct = shift;
	# 0 = kapalı: `off` rengi ve parlaklığı KORUR, yalnız sönük işaretler —
	# döngü bir sonraki adımda aynı renge geri açabilsin diye.
	run($pct == 0 ? 'kbd-rgb off' : "kbd-rgb bright $pct");
	return $pct == 0 ? 'aydınlatma KAPALI' : "aydınlatma %$pct";
}

# Touchpad: COSMIC'te programatik anahtar yok; i2c-hid sürücüsünü bağla/çöz.
# Geri alınabilir ve toggle: bind varsa unbind, yoksa bind.
sub act_touchpad {
	my $drv = '/sys/bus/i2c/drivers/i2c_hid_acpi';
	my ($dev) = map { m{/([^/]+)$} ? $1 : () } glob "$drv/i2c-ELAN*";
	unless ($dev) {
		# bağlı değil → geri bağla (ad sabit: ELAN0A05:00, ölçüldü 16 Eyl 2026)
		$dev = 'i2c-ELAN0A05:00';
		write_to("$drv/bind", $dev) or return 'touchpad geri bağlanamadı';
		return 'touchpad AÇIK';
	}
	write_to("$drv/unbind", $dev) or return 'touchpad kapatılamadı';
	return 'touchpad KAPALI';
}

sub run { my $c = shift; system("$c >/dev/null 2>&1"); }
sub slurp { open(my $f, '<', shift) or return '?'; my $v = <$f>; close $f; chomp $v; $v }
sub write_to {
	my ($p, $v) = @_;
	open(my $f, '>', $p) or return 0;
	my $ok = print {$f} $v;
	close $f;
	return $ok;
}

# --- kaynak: 0xFF02 taşıyan hidraw düğümü (numara kararlı değil, descriptor'a bak)
my $src;
for my $p (glob "/sys/class/hidraw/hidraw*") {
	my ($n) = $p =~ m{(hidraw\d+)$};
	open(my $u, '<', "$p/device/uevent") or next;
	my $txt = do { local $/; <$u> }; close $u;
	next unless $txt =~ /HID_ID=0003:00000414:00008104/i;
	open(my $r, '<:raw', "$p/device/report_descriptor") or next;
	my $d = do { local $/; <$r> }; close $r;
	next unless $d =~ /\x06\x02\xFF/;     # Usage Page 0xFF02
	$src = "/dev/$n";
	last;
}
die "0xFF02 taşıyan hidraw düğümü bulunamadı (klavye takılı mı?)\n" unless $src;
open(my $hid, '<:raw', $src) or die "$src: $! — root gerekiyor\n";
print "kaynak: $src\n";

# --- hedef: uinput sanal klavyesi -----------------------------------------
open(my $ui, '+<', '/dev/uinput') or die "/dev/uinput: $! (modül yüklü mü?)\n";
use constant { UI_SET_EVBIT => 0x40045564, UI_SET_KEYBIT => 0x40045565,
               UI_DEV_CREATE => 0x5501, UI_DEV_DESTROY => 0x5502,
               EV_SYN => 0, EV_KEY => 1 };
ioctl($ui, UI_SET_EVBIT, EV_KEY) or die "UI_SET_EVBIT: $!\n";
# İKİ tablodan da kaydet: %MAP1'in tuşları (KEY_KBDILLUM*) buradan geçmezse
# uinput onları yok sayar ve aydınlatma basışları evdev'e hiç ulaşmaz.
ioctl($ui, UI_SET_KEYBIT, $_) or die "UI_SET_KEYBIT: $!\n"
	for map { $_->[0] } (values %MAP, values %MAP1);

# uinput_user_dev (eski API): name[80] + input_id + ff_effects_max + 4×64 abs
my $dev = pack('a80 S S S S l', 'AERO X16 Fn koprusu', 0x03, 0x0414, 0x8104, 1, 0)
        . ("\0" x (64 * 4 * 4));
syswrite($ui, $dev) or die "uinput_user_dev yazılamadı: $!\n";
ioctl($ui, UI_DEV_CREATE, 0) or die "UI_DEV_CREATE: $!\n";
printf("sanal klavye hazır — %s modu, köprü çalışıyor (Ctrl-C bitirir)\n",
	$ACT ? "TUŞ + EYLEM" : "yalnız tuş");
# Güvenlik ağı: --act touchpad.i kapatmışken köprü ölürse kullanıcı touchpad.siz
# kalır. Çıkışta geri bağla — kapatma kararı köprüye ait, kalıcılığı değil.
$SIG{INT} = $SIG{TERM} = sub {
	if ($ACT && !glob '/sys/bus/i2c/drivers/i2c_hid_acpi/i2c-ELAN*') {
		write_to('/sys/bus/i2c/drivers/i2c_hid_acpi/bind', 'i2c-ELAN0A05:00');
		print "\ntouchpad geri bağlandı (çıkış temizliği)\n";
	}
	ioctl($ui, UI_DEV_DESTROY, 0); close $ui; exit 0;
};

# --- döngü ------------------------------------------------------------------
my %last;
while (1) {
	my $buf = '';
	my $got = sysread($hid, $buf, 64) or next;
	my @b = unpack('C*', substr($buf, 0, $got));
	next unless @b >= 4 && $b[0] == 4;
	# Kodun HANGİ BAYTTA olduğunu ikinci bayt söyler (bkz. %MAP1 notu):
	#   tür 0 → "04 00 00 <kod>",  tür 1 → "04 01 <kod> 00".
	my ($tur, $code) = $b[1] == 1 ? (1, $b[2]) : (0, $b[3]);
	# Debounce anahtarı TÜRÜ de taşımak zorunda: iki tablonun kod uzayları
	# ayrı ve ikisinde de 0x00 görülebiliyor — tek anahtar olsaydı bir türün
	# basışı diğerininkini 250 ms boyunca yutardı.
	my $anahtar = "$tur:$code";
	my $now  = now();
	if (($last{$anahtar} // 0) + $DEBOUNCE > $now) {
		printf("  yok sayıldı (debounce): tür%d 0x%02X\n", $tur, $code) if $DEBUG;
		next;
	}
	$last{$anahtar} = $now;
	my $m = $tur == 1 ? $MAP1{$code} : $MAP{$code};
	if (!$m) {
		printf("EŞLENMEMİŞ 0xFF02 kodu: tür%d 0x%02X  (%s) — fn-keys.md'ye ekle\n",
			$tur, $code, join(' ', map { sprintf('%02X', $_) } @b));
		next;
	}
	emit(EV_KEY, $m->[0], 1); emit(EV_SYN, 0, 0);
	emit(EV_KEY, $m->[0], 0); emit(EV_SYN, 0, 0);
	printf("0x%02X → %s   (%s)", $code, $m->[1], $m->[2]);
	# GNOME KEY_MICMUTE ve KEY_TOUCHPAD_TOGGLE'ı KENDİSİ işler. O oturumdayken
	# eylemi biz de yaparsak aynı basış iki kez işlenir ve mikrofon aynı yere
	# döner. Tuşu yine üretiyoruz (doğru katman orası), eylemi GNOME'a bırakıyoruz.
	if ($ACT && $m->[4] && gnome_running()) {
		print "   ⇒ eylem GNOME'a bırakıldı\n";
	} else {
		print $ACT ? "   ⇒ " . ($m->[3]->() // '') . "\n" : "\n";
	}
}

sub emit {
	my ($type, $code, $val) = @_;
	syswrite($ui, pack('q q S S l', 0, 0, $type, $code, $val));
}

sub now {
	open(my $f, '<', '/proc/uptime') or return time();
	my $l = <$f>; close $f;
	return (split ' ', $l)[0];
}

# GNOME oturumu ayakta mı? (COSMIC'te hiçbir şey değişmez — orada eylem bizde.)
sub gnome_running {
	return -d '/proc' && system('pgrep -x gnome-shell >/dev/null 2>&1') == 0;
}
