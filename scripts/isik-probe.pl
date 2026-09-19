#!/usr/bin/env perl
# isik-probe.pl — 0xFF02 kanalındaki IŞIK tuşlarını haritalar.
#
# fn-probe.pl'den farkı: iki alt-protokolü de doğru çözer.
#   04 00 00 <kod>   → bilinen tuşlar (Fn+F4/F7/F9)      kod = bayt 3
#   04 01 <kod> 00   → YENİ sınıf (19 Eyl 2026'da bulundu) kod = bayt 2
# Adımları sırayla sorar, her adımda N saniye dinler, gelen kodu o adıma yazar.
use strict; use warnings;
use Time::HiRes qw(time);
$| = 1;

# --- 0xFF02 taşıyan düğümü descriptor imzasından bul (numara kararsız) ------
my $src;
for my $p (glob "/sys/class/hidraw/hidraw*") {
	my ($n) = $p =~ m{(hidraw\d+)$};
	open(my $u, '<', "$p/device/uevent") or next;
	my $t = do { local $/; <$u> }; close $u;
	next unless $t =~ /HID_ID=0003:00000414:00008104/i;
	open(my $d, '<:raw', "$p/device/report_descriptor") or next;
	my $raw = do { local $/; <$d> }; close $d;
	next unless index($raw, pack('C3', 0x06, 0x02, 0xFF)) >= 0;
	$src = "/dev/$n"; last;
}
die "0xFF02 düğümü bulunamadı\n" unless $src;
open(my $hid, '<:raw', $src) or die "$src: $!\n";
print "kaynak: $src\n\n";

my @ADIM = (
	['Fn+Space',          4],
	['Fn+Space (tekrar)', 4],
	['Fn+YUKARI ok',      3],
	['Fn+ASAGI ok',       3],
	['Fn+SOL ok',         3],
	['Fn+SAG ok',         3],
	['Fn+Esc',            3],
	['Fn+Tab',            3],
	['Fn+Backspace',      3],
	['Fn+F5 (referans)',  3],
);

my %harita;
for my $a (@ADIM) {
	my ($ad, $sure) = @$a;
	printf("%-22s -> SIMDI BAS  (%d sn)", $ad, $sure);
	my @gelen;
	my $son = time + $sure;
	while ((my $kalan = $son - time) > 0) {
		my $rin = ''; vec($rin, fileno($hid), 1) = 1;
		next unless select(my $rout = $rin, undef, undef, $kalan) > 0;
		my $buf = '';
		my $got = sysread($hid, $buf, 64) or next;
		my @b = unpack('C*', substr($buf, 0, $got));
		next unless @b >= 4 && $b[0] == 4;
		# iki alt-protokol: tür baytı $b[1] hangisini söylüyor
		my ($tur, $kod) = $b[1] == 1 ? ('01', $b[2]) : ('00', $b[3]);
		push @gelen, sprintf("tur=%s kod=0x%02X [%s]", $tur, $kod,
			join(' ', map { sprintf('%02X', $_) } @b[0..3]));
	}
	if (@gelen) {
		print "  ✔\n";
		print "      $_\n" for @gelen;
		$harita{$ad} = \@gelen;
	} else {
		print "  — (hicbir kanala dusmedi)\n";
	}
}

print "\n=== OZET ===\n";
for my $a (@ADIM) {
	my ($ad) = @$a;
	printf("%-22s %s\n", $ad, $harita{$ad} ? join(' | ', @{$harita{$ad}}) : 'YOK — klavye icinde yutuluyor');
}
