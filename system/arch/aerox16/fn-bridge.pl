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
ioctl($ui, UI_SET_KEYBIT, $MAP{$_}[0]) or die "UI_SET_KEYBIT: $!\n" for keys %MAP;

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
	my $code = $b[3];
	my $now  = now();
	if (($last{$code} // 0) + $DEBOUNCE > $now) {
		print "  yok sayıldı (debounce): 0x" . sprintf('%02X', $code) . "\n" if $DEBUG;
		next;
	}
	$last{$code} = $now;
	my $m = $MAP{$code};
	if (!$m) {
		printf("EŞLENMEMİŞ 0xFF02 kodu: 0x%02X  (%s) — fn-keys.md'ye ekle\n",
			$code, join(' ', map { sprintf('%02X', $_) } @b));
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
