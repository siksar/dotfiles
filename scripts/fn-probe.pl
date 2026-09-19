#!/usr/bin/env perl
# fn-probe.pl — AERO X16 (EG61H) Fn kombinasyonlarını DÖRT kanalda birden dinler.
#
# Neden dört kanal: bu makinede bir Fn kombinasyonu dört ayrı yoldan çıkabilir
# (ayrıntı: Documentation/aerox16/fn-keys.md):
#   1. dahili klavye (0414:8104) standart HID klavye/consumer raporu   → hidraw
#   2. satıcı sayfası 0xFF02 Report ID 4 — Linux'un YOK SAYDIĞI kanal   → hidraw
#   3. evdev'e dönüşmüş tuş kodu (çekirdek eşlemesi tuttuysa)           → /dev/input
#   4. EC → _Q45 → WMI olayı (aero_eg61h "EC olayi" satırı)             → journal
# Bir kombinasyon hiçbir kanalda görünmüyorsa EC onu KENDİ içinde yutuyordur.
#
# Kullanım:  sudo perl scripts/fn-probe.pl            (Ctrl-C ile bitir)
#            sudo perl scripts/fn-probe.pl --list     (yalnız kanalları göster)
# Protokol:  her kombinasyona 1 kez bas, ~2 s bekle, sıradakine geç. Çıktıyı
#            defterdeki tabloya işle.
use strict;
use warnings;

$| = 1;   # timeout/Ctrl-C ile kesilince tampon kaybolmasın

my $VID = '0414';
my $PID = '8104';
my $LIST = grep { $_ eq '--list' } @ARGV;

# --- kanal 1-2: dahili klavyenin hidraw düğümleri -------------------------
my @hid;
for my $p (glob "/sys/class/hidraw/hidraw*") {
	my ($n) = $p =~ m{(hidraw\d+)$};
	my $ue = "$p/device/uevent";
	open(my $f, '<', $ue) or next;
	my $txt = do { local $/; <$f> };
	close $f;
	next unless $txt =~ /HID_ID=0003:0000\Q$VID\E:0000\Q$PID\E/i;
	my ($phys) = $txt =~ /HID_PHYS=(\S+)/;
	my $iface = hid_role("$p/device/report_descriptor");
	push @hid, { dev => "/dev/$n", name => $n, iface => $iface, phys => $phys // '' };
}

# report_descriptor'dan kısa rol etiketi — hangi düğümün ne taşıdığını
# ezberlemek yerine descriptor söylesin (fn-keys.md "Klavye HID haritası").
sub hid_role {
	my $f = shift;
	open(my $h, '<:raw', $f) or return '?';
	local $/; my @b = unpack('C*', <$h>); close $h;
	my @pg; my $i = 0;
	while ($i <= $#b) {
		my $sz = $b[$i] & 3; $sz = 4 if $sz == 3;
		if (($b[$i] & 0xFC) == 0x04) {
			my $v = 0; $v |= $b[$i+1+$_] << (8*$_) for 0..$sz-1;
			push @pg, $v unless grep { $_ == $v } @pg;
		}
		$i += 1 + $sz;
	}
	my %n = (1=>'desktop', 7=>'klavye', 8=>'led', 9=>'düğme', 0x0C=>'consumer',
		0x59=>'LampArray', 0xFF00=>'satıcı-FF00', 0xFF01=>'satıcı-FF01',
		0xFF02=>'SATICI-FF02', 0xFF89=>'satıcı-FF89');
	return join(',', map { $n{$_} // sprintf('%#x', $_) } @pg);
}

# --- kanal 3: aynı cihazın evdev düğümleri --------------------------------
my @evd;
{
	open(my $f, '<', '/proc/bus/input/devices') or die "input/devices: $!";
	local $/ = "";
	while (my $blk = <$f>) {
		next unless $blk =~ /Vendor=\Q$VID\E\s+Product=\Q$PID\E/i;
		my ($nm)  = $blk =~ /N: Name="([^"]*)"/;
		my ($hnd) = $blk =~ /H: Handlers=(.*)/;
		for my $ev ($hnd =~ /(event\d+)/g) {
			push @evd, { dev => "/dev/input/$ev", name => $ev, label => $nm // '' };
		}
	}
	close $f;
}

printf("kanal: %-16s %-34s %s\n", $_->{dev}, $_->{iface}, $_->{phys}) for @hid;
printf("kanal: %-16s %s\n", $_->{dev}, $_->{label}) for @evd;
print "kanal: journalctl -kf  (aero_eg61h 'EC olayi' = EC→_Q45→WMI)\n";
exit 0 if $LIST;

# --- açılış ----------------------------------------------------------------
my %fh;
for my $h (@hid) {
	if (open(my $f, '<:raw', $h->{dev})) { $fh{fileno $f} = { h => $f, kind => 'hid', tag => $h->{name}.' ('.$h->{iface}.')' } }
	else { warn "$h->{dev}: $! — root gerekiyor\n" }
}
for my $e (@evd) {
	if (open(my $f, '<:raw', $e->{dev})) { $fh{fileno $f} = { h => $f, kind => 'evd', tag => $e->{name}.' '.$e->{label} } }
	else { warn "$e->{dev}: $!\n" }
}
if (open(my $j, '-|', 'journalctl -kf -n0 -o cat')) {
	$fh{fileno $j} = { h => $j, kind => 'jrn', tag => 'kernel' };
} else { warn "journalctl açılamadı: $!\n" }
die "hiçbir kanal açılamadı\n" unless %fh;

my $rin = '';
vec($rin, $_, 1) = 1 for keys %fh;
my $t0 = time_hi();
print "\n--- dinleniyor; Fn kombinasyonuna bas, ~2 s bekle, sıradakine geç (Ctrl-C bitirir) ---\n";

# EV_KEY kod → ad (yalnız bu makinede beklenenler; gerisi sayı olarak basılır)
my %KEY = (
	113=>'MUTE', 114=>'VOLUMEDOWN', 115=>'VOLUMEUP', 142=>'SLEEP', 190=>'F20',
	212=>'CAMERA', 224=>'BRIGHTNESSDOWN', 225=>'BRIGHTNESSUP', 226=>'MEDIA',
	227=>'SWITCHVIDEOMODE', 228=>'KBDILLUMTOGGLE', 229=>'KBDILLUMDOWN',
	230=>'KBDILLUMUP', 247=>'RFKILL', 248=>'MICMUTE', 464=>'FN', 530=>'TOUCHPAD_TOGGLE',
	431=>'PROG3', 432=>'PROG4', 148=>'PROG1', 149=>'PROG2',
);
my %TYPE = (0=>'SYN', 1=>'KEY', 4=>'MSC', 5=>'SW');

while (1) {
	my $r = $rin;
	my $n = select($r, undef, undef, undef);
	next if $n <= 0;
	for my $fd (keys %fh) {
		next unless vec($r, $fd, 1);
		my $e = $fh{$fd};
		if ($e->{kind} eq 'jrn') {
			my $line = readline $e->{h};
			next unless defined $line;
			next unless $line =~ /EC olayi|EC event/;
			chomp $line;
			out('WMI ', $line);
		} elsif ($e->{kind} eq 'hid') {
			my $buf = '';
			my $got = sysread($e->{h}, $buf, 64);
			next unless $got;
			my @b = unpack('C*', substr($buf, 0, $got));
			out('HID ', sprintf("%-14s %s%s", $e->{tag},
				join(' ', map { sprintf('%02X', $_) } @b), decode_hid(\@b)));
		} else {
			my $buf = '';
			my $got = sysread($e->{h}, $buf, 24 * 16);
			next unless $got;
			for (my $i = 0; $i + 24 <= $got; $i += 24) {
				my (undef, undef, $type, $code, $val) = unpack('q q S S l', substr($buf, $i, 24));
				next if $type == 0;               # SYN gürültüsü
				next if $type == 4;               # MSC_SCAN
				out('EVD ', sprintf("%-28s %s code=%d%s value=%d", $e->{tag},
					$TYPE{$type} // "t$type", $code,
					$KEY{$code} ? " ($KEY{$code})" : '', $val));
			}
		}
	}
}

sub out {
	my ($ch, $txt) = @_;
	printf("[%7.3f] %s %s\n", time_hi() - $t0, $ch, $txt);
	$| = 1;
}

sub time_hi {
	my @t = gettimeofday_pure();
	return $t[0] + $t[1] / 1e6;
}

# Time::HiRes'e bağlanmamak için: /proc/uptime yeterli çözünürlükte (10 ms).
sub gettimeofday_pure {
	open(my $f, '<', '/proc/uptime') or return (time(), 0);
	my $l = <$f>; close $f;
	my ($s) = split ' ', $l;
	return (int($s), int(($s - int($s)) * 1e6));
}

# Bilinen rapor kimliklerini adlandır (descriptor: fn-keys.md "Klavye HID haritası")
sub decode_hid {
	my ($b) = @_;
	return '' unless @$b;
	my $id = $b->[0];
	if ($id == 3 && @$b >= 3) {
		my $u = $b->[1] | ($b->[2] << 8);
		return sprintf('   ← Consumer usage 0x%03X%s', $u, $u ? '' : ' (bırakma)');
	}
	return '   ← SATICI 0xFF02 (Linux bunu yok sayar)' if $id == 4;
	return '   ← Wireless Radio (rfkill)'              if $id == 7;
	return '   ← klavye NKRO'                          if $id == 5;
	return '';
}
