// kbd-rgb — AERO X16 1VH klavye aydınlatması (HID LampArray, Usage Page 0x59)
//
// Protokol yayımlanmış bir standart: USB HID Usage Tables v1.4 §26
// ("Lighting And Illumination Page"). Windows 11'in "Dynamic Lighting"
// özelliği de bunu sürüyor — bu yüzden reverse-engineering YOK, DSDT/EC
// tahmini YOK (fan/güç tarafındaki WMBD selector kazısının aksine).
//
// Bu makinede ölçülen cihaz profili (docs/aerox16-keyboard-rgb.md):
//   LampCount = 1            → tek bölge; tuş-başına efekt MÜMKÜN DEĞİL
//   R/G/B kademe = 255 her biri → tam 8-bit renk
//   IntensityLevelCount = 1  → ayrı parlaklık kanalı YOK; parlaklık ancak
//                              RGB değerlerini ölçekleyerek yapılır
//   LampArrayKind = 6 (Notification), sınırlayıcı kutu 1.2x1.6cm
//     → firmware metadata'sı YANLIŞ; gerçekte tüm klavyeyi sürüyor (ölçüldü)
//
// Bağımlılık yok: ioctl'i doğrudan bildiriyoruz, böylece libc crate'i bile
// gerekmiyor → Cargo/vendoring/cargoHash yok, `rustc -O main.rs` yetiyor.

use std::fs;
use std::io::{self, Write};
use std::os::unix::io::AsRawFd;
use std::path::PathBuf;
use std::time::{Duration, Instant};

extern "C" {
    fn ioctl(fd: i32, request: u64, arg: *mut u8) -> i32;
}

// _IOC(dir=READ|WRITE, type='H', nr, size) — linux/hidraw.h
fn hidioc(nr: u64, len: usize) -> u64 {
    0xC000_0000 | ((len as u64) << 16) | (0x48 << 8) | nr
}

struct Lamp {
    f: fs::File,
    count: u16,
}

impl Lamp {
    /// Descriptor'da LampArray imzasını arayarak cihazı bulur.
    /// hidraw NUMARASI KARARLI DEĞİL (boot'tan boot'a değişir) — bu yüzden
    /// asla /dev/hidraw8 gibi sabit yol kullanmıyoruz.
    fn find() -> io::Result<PathBuf> {
        // 05 59 = Usage Page (Lighting And Illumination)
        // 09 01 = Usage (LampArray), a1 01 = Collection (Application)
        const SIG: &[u8] = &[0x05, 0x59, 0x09, 0x01, 0xA1, 0x01];
        let mut found: Vec<PathBuf> = Vec::new();
        for e in fs::read_dir("/sys/class/hidraw")? {
            let e = e?;
            let name = e.file_name().to_string_lossy().into_owned();
            if !name.starts_with("hidraw") {
                continue;
            }
            let desc = e.path().join("device/report_descriptor");
            if let Ok(d) = fs::read(&desc) {
                if d.windows(SIG.len()).any(|w| w == SIG) {
                    found.push(PathBuf::from(format!("/dev/{}", name)));
                }
            }
        }
        found.sort();
        found.into_iter().next().ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::NotFound,
                "LampArray cihazı bulunamadı (udev kuralı yüklü mü? \
                 'kbd-rgb info' ile bak)",
            )
        })
    }

    fn open() -> io::Result<Self> {
        let path = Self::find()?;
        let f = fs::OpenOptions::new()
            .read(true)
            .write(true)
            .open(&path)
            .map_err(|e| {
                io::Error::new(
                    e.kind(),
                    format!(
                        "{} açılamadı: {} (udev uaccess kuralı çalışmıyor olabilir)",
                        path.display(),
                        e
                    ),
                )
            })?;
        let mut l = Lamp { f, count: 1 };
        l.count = l.attrs()?.0.max(1);
        Ok(l)
    }

    fn get_feature(&self, id: u8, len: usize) -> io::Result<Vec<u8>> {
        let mut buf = vec![0u8; len];
        buf[0] = id;
        let r = unsafe { ioctl(self.f.as_raw_fd(), hidioc(0x07, len), buf.as_mut_ptr()) };
        if r < 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(buf)
    }

    fn set_feature(&self, buf: &mut [u8]) -> io::Result<()> {
        let r = unsafe { ioctl(self.f.as_raw_fd(), hidioc(0x06, buf.len()), buf.as_mut_ptr()) };
        if r < 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(())
    }

    /// LampArrayAttributesReport (id=1): (lamba sayısı, cihaz türü)
    fn attrs(&self) -> io::Result<(u16, u32)> {
        let b = self.get_feature(1, 23)?;
        Ok((
            u16::from_le_bytes([b[1], b[2]]),
            u32::from_le_bytes([b[15], b[16], b[17], b[18]]),
        ))
    }

    /// LampArrayControlReport (id=6): firmware efektlerini aç/kapa.
    /// Renk yazmadan ÖNCE kapatmak şart, yoksa firmware üstüne yazar.
    fn autonomous(&self, on: bool) -> io::Result<()> {
        self.set_feature(&mut [6u8, u8::from(on)])
    }

    /// LampRangeUpdateReport (id=5): tüm lambalara tek renk.
    /// Intensity alanı 255 sabit — bu cihazda kanal 1 kademeli, işlevsiz.
    fn color(&self, (r, g, b): Rgb) -> io::Result<()> {
        let mut buf = [0u8; 10];
        buf[0] = 5;
        buf[1] = 1; // LampUpdateFlags: LampUpdateComplete → atomik uygula
        buf[2..4].copy_from_slice(&0u16.to_le_bytes());
        buf[4..6].copy_from_slice(&(self.count - 1).to_le_bytes());
        buf[6] = r;
        buf[7] = g;
        buf[8] = b;
        buf[9] = 255;
        self.set_feature(&mut buf)
    }
}

type Rgb = (u8, u8, u8);

const PRESETS: &[(&str, Rgb)] = &[
    ("red", (255, 0, 0)),
    ("green", (0, 255, 0)),
    ("blue", (0, 0, 255)),
    ("cyan", (0, 255, 255)),
    ("magenta", (255, 0, 255)),
    ("yellow", (255, 255, 0)),
    ("orange", (255, 120, 0)),
    ("purple", (160, 0, 255)),
    ("pink", (255, 80, 160)),
    ("white", (255, 255, 255)),
    ("off", (0, 0, 0)),
];

fn parse_color(s: &str) -> Result<Rgb, String> {
    let t = s.trim().trim_start_matches('#');
    if let Some(&(_, c)) = PRESETS.iter().find(|(n, _)| *n == s.trim()) {
        return Ok(c);
    }
    if t.len() == 6 {
        if let Ok(v) = u32::from_str_radix(t, 16) {
            return Ok((((v >> 16) & 0xFF) as u8, ((v >> 8) & 0xFF) as u8, (v & 0xFF) as u8));
        }
    }
    Err(format!(
        "renk çözümlenemedi: '{}' (hex 'ff6400' veya ön ayar: {})",
        s,
        PRESETS.iter().map(|(n, _)| *n).collect::<Vec<_>>().join(", ")
    ))
}

fn scale((r, g, b): Rgb, pct: u32) -> Rgb {
    let f = |v: u8| ((v as u32 * pct + 50) / 100).min(255) as u8;
    (f(r), f(g), f(b))
}

fn hsv(h: f64, s: f64, v: f64) -> Rgb {
    let c = v * s;
    let x = c * (1.0 - ((h / 60.0) % 2.0 - 1.0).abs());
    let m = v - c;
    let (r, g, b) = match h as u32 {
        0..=59 => (c, x, 0.0),
        60..=119 => (x, c, 0.0),
        120..=179 => (0.0, c, x),
        180..=239 => (0.0, x, c),
        240..=299 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    let q = |t: f64| (((t + m) * 255.0) + 0.5) as u8;
    (q(r), q(g), q(b))
}

// --- Durum: temel renk + parlaklık yüzdesi + açık/kapalı ------------------
// Parlaklık ayrı bir donanım kanalı OLMADIĞI için (IntensityLevelCount=1)
// "temel renk"i saklayıp ölçekliyoruz; yoksa parlaklığı düşürmek rengi
// geri döndürülemez biçimde kaybettirirdi.
//
// AÇIK/KAPALI ÜÇÜNCÜ ALAN OLARAK (19 Eyl 2026): `off` eskiden yalnız (0,0,0)
// yazıyor, duruma HİÇ DOKUNMUYORDU — yani "hangi renge geri açacağız" bilgisi
// saklanmıyordu ve `toggle` yazılamıyordu. Fn+kombinasyon ve COSMIC GUI'sinin
// ikisi de aç/kapa istiyor, bu yüzden durum üç alanlı oldu.
//
// Dosya formatı: "<hex> <yüzde> <on|off>". ÜÇÜNCÜ ALAN YOKSA eski iki alanlı
// dosyadır ve `on` varsayılır — eski state dosyaları kırılmaz.

fn state_file() -> PathBuf {
    let base = std::env::var("XDG_STATE_HOME").unwrap_or_else(|_| {
        format!(
            "{}/.local/state",
            std::env::var("HOME").unwrap_or_else(|_| "/tmp".into())
        )
    });
    PathBuf::from(base).join("kbd-rgb/state")
}

fn load_state() -> (Rgb, u32, bool) {
    let d = fs::read_to_string(state_file()).unwrap_or_default();
    let mut it = d.split_whitespace();
    let c = it.next().and_then(|s| parse_color(s).ok()).unwrap_or((255, 255, 255));
    let p = it.next().and_then(|s| s.parse().ok()).unwrap_or(100u32).clamp(0, 100);
    // eski iki alanlı dosyada üçüncü alan yok → None gelir → "on" sayılır
    let on = !matches!(it.next(), Some("off"));
    (c, p, on)
}

/// ATOMİK yazma (tmp + rename). Bu dosyanın artık ÜÇ yazarı var — oturum
/// açılışındaki kbd-rgb-theme.service, Fn köprüsü ve GUI — ve animasyon
/// döngüsü onu 0.5 sn'de bir OKUYOR. Düz `fs::write` yarım yazılmış dosya
/// okutabilirdi; `rename` POSIX'te atomiktir.
fn save_state((r, g, b): Rgb, pct: u32, on: bool) {
    let p = state_file();
    if let Some(d) = p.parent() {
        let _ = fs::create_dir_all(d);
    }
    // pid son eki: iki yazar geçici dosyada çakışmasın
    let tmp = p.with_extension(format!("tmp.{}", std::process::id()));
    let body = format!(
        "{:02x}{:02x}{:02x} {} {}\n",
        r, g, b, pct, if on { "on" } else { "off" }
    );
    if fs::write(&tmp, body).is_ok() && fs::rename(&tmp, &p).is_err() {
        let _ = fs::remove_file(&tmp);
    }
}

/// Işığı YAK: temel rengi parlaklıkla ölçekleyip yaz, durumu "on" kaydet.
fn apply(l: &Lamp, base: Rgb, pct: u32) -> io::Result<()> {
    l.autonomous(false)?;
    l.color(scale(base, pct))?;
    save_state(base, pct, true);
    Ok(())
}

/// Işığı SÖNDÜR: (0,0,0) yaz ama temel rengi ve parlaklığı KORU — `on` ve
/// `toggle` tam olarak bu değerlerle geri açar.
fn extinguish(l: &Lamp, base: Rgb, pct: u32) -> io::Result<()> {
    l.autonomous(false)?;
    l.color((0, 0, 0))?;
    save_state(base, pct, false);
    Ok(())
}

fn usage() -> ! {
    eprintln!(
        "kullanım: kbd-rgb <komut>

  info                     cihaz bilgisi (lamba sayısı, hidraw yolu, durum)
  status [--json]          yalnız durum; --json makine-okunur (GUI/betik için)
  set <renk>               renk ata — hex 'ff6400' ya da ön ayar adı
  on                       son renk ve parlaklıkla yak
  off                      söndür (renk ve parlaklık KORUNUR)
  toggle                   yanıyorsa söndür, sönükse yak
  bright <+N|-N|N>         parlaklık %% — RGB ölçekleme, kalıcı; sönükse yakar
  auto <on|off>            firmware efektlerini aç/kapa
  anim <breathe|rainbow> [--fps N]
                           animasyon; ön planda çalışır (systemd yönetir)

ön ayarlar: {}",
        PRESETS.iter().map(|(n, _)| *n).collect::<Vec<_>>().join(", ")
    );
    std::process::exit(2)
}

fn run() -> io::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() {
        usage();
    }
    let (base, pct, on) = load_state();

    match args[0].as_str() {
        "info" => {
            let path = Lamp::find()?;
            let l = Lamp::open()?;
            let (count, kind) = l.attrs()?;
            println!("cihaz        : {}", path.display());
            println!("lamba sayısı : {}", count);
            println!("cihaz türü   : {} (firmware'in bildirdiği; bu modelde yanıltıcı)", kind);
            println!(
                "durum        : #{:02x}{:02x}{:02x} @ %{} — {}",
                base.0, base.1, base.2, pct,
                if on { "açık" } else { "kapalı" }
            );
        }
        // Cihaza DOKUNMADAN da cevap verir: GUI paneli klavye takılı değilken
        // de durumu gösterebilsin, açılışta hata kutusu atmasın.
        "status" => {
            let dev = Lamp::find().ok();
            let (count, kind) = Lamp::open()
                .ok()
                .and_then(|l| l.attrs().ok())
                .unwrap_or((0, 0));
            if args.iter().any(|a| a == "--json") {
                // Elle basılıyor: sıfır crate bağımlılığı kuralı (package.nix
                // `rustc -O main.rs`) serde'yi dışarıda tutuyor. Alanların
                // hiçbiri kullanıcı metni taşımıyor, kaçış gerekmiyor.
                println!(
                    "{{\"device\":{},\"lamps\":{},\"kind\":{},\"color\":\"{:02x}{:02x}{:02x}\",\"brightness\":{},\"on\":{}}}",
                    dev.map(|p| format!("\"{}\"", p.display()))
                        .unwrap_or_else(|| "null".into()),
                    count, kind, base.0, base.1, base.2, pct, on
                );
            } else {
                println!("renk      : #{:02x}{:02x}{:02x}", base.0, base.1, base.2);
                println!("parlaklık : %{}", pct);
                println!("durum     : {}", if on { "açık" } else { "kapalı" });
                println!(
                    "cihaz     : {}",
                    dev.map(|p| p.display().to_string())
                        .unwrap_or_else(|| "BULUNAMADI".into())
                );
            }
        }
        "set" => {
            let c = parse_color(args.get(1).unwrap_or(&String::new()))
                .map_err(|e| io::Error::new(io::ErrorKind::InvalidInput, e))?;
            apply(&Lamp::open()?, c, pct)?;
        }
        "on" => {
            apply(&Lamp::open()?, base, pct)?;
        }
        "off" => {
            extinguish(&Lamp::open()?, base, pct)?;
        }
        // Fn+kombinasyonun ve GUI düğmesinin ikisi de bunu çağırır. Durum
        // dosyasındaki `on` alanı tek gerçek kaynak — LampArray'de yazılan
        // renk geri OKUNAMADIĞI için donanıma sorma seçeneği yok.
        "toggle" => {
            let l = Lamp::open()?;
            if on {
                extinguish(&l, base, pct)?;
            } else {
                apply(&l, base, pct)?;
            }
            println!("{}", if on { "söndürüldü" } else { "yakıldı" });
        }
        "bright" => {
            let a = args.get(1).map(String::as_str).unwrap_or("");
            let new = if let Some(d) = a.strip_prefix('+') {
                pct + d.parse::<u32>().unwrap_or(10)
            } else if let Some(d) = a.strip_prefix('-') {
                pct.saturating_sub(d.parse::<u32>().unwrap_or(10))
            } else {
                a.parse::<u32>()
                    .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "parlaklık sayı olmalı"))?
            }
            .clamp(0, 100);
            // Sönükken parlaklık tuşuna basmak ışığı YAKAR — donanımdaki
            // davranış da bu, ve apply() zaten durumu "on" kaydeder.
            apply(&Lamp::open()?, base, new)?;
            println!("parlaklık: %{}", new);
        }
        "auto" => {
            let on = matches!(args.get(1).map(String::as_str), Some("on"));
            Lamp::open()?.autonomous(on)?;
        }
        "anim" => {
            let mode = args.get(1).cloned().unwrap_or_else(|| "breathe".into());
            let fps: u64 = args
                .iter()
                .position(|a| a == "--fps")
                .and_then(|i| args.get(i + 1))
                .and_then(|s| s.parse().ok())
                .unwrap_or(60)
                .clamp(1, 240);

            let l = Lamp::open()?;
            l.autonomous(false)?;
            let dt = Duration::from_micros(1_000_000 / fps);
            let t0 = Instant::now();

            // Durumu yarım saniyede bir tazele. Böylece animasyon DÖNERKEN
            // `kbd-rgb set` (tema servisi), `kbd-rgb bright` ya da `toggle`
            // (Fn tuşu / GUI) çalışırsa efekt canlı uyum sağlar — iki yazarın
            // aynı lambayı çekiştirip titretmesi yerine tek otorite döngü olur.
            let (mut base, mut pct, mut on) = (base, pct, on);
            let mut refreshed = Instant::now();

            // Sonsuz döngü: systemd durdurur (ExecStopPost `auto on` ile
            // firmware efektlerini iade eder). Sinyal yakalamaya gerek yok.
            loop {
                if refreshed.elapsed() >= Duration::from_millis(500) {
                    let (b, p, o) = load_state();
                    base = b;
                    pct = p;
                    on = o;
                    refreshed = Instant::now();
                }
                let t = t0.elapsed().as_secs_f64();
                // Animasyon dönerken söndürüldüyse (Fn+Space) karanlık kal —
                // döngüyü öldürmeye gerek yok, durum "on"a dönünce devam eder.
                let c = if !on {
                    (0, 0, 0)
                } else {
                    match mode.as_str() {
                        "rainbow" => hsv((t * 45.0) % 360.0, 1.0, 1.0),
                        // nefes: 4 sn periyot, %8 taban (tamamen sönmesin)
                        _ => {
                            let k = (1.0 - (t * std::f64::consts::TAU / 4.0).cos()) / 2.0;
                            scale(base, (8.0 + k * 92.0) as u32)
                        }
                    }
                };
                l.color(scale(c, pct))?;
                std::thread::sleep(dt);
            }
        }
        _ => usage(),
    }
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        let _ = writeln!(io::stderr(), "kbd-rgb: {}", e);
        std::process::exit(1);
    }
}
