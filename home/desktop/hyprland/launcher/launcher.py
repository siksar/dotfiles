"""hypr-launcher — waybar adasının içinde açılan başlatıcı (SUPER+Space).

Arka planda HAZIR bekleyen bir servis (session.nix, hypr-launcher.service):
uygulama dizini, simgeler ve pencere bir kez kurulur, tuşa basılınca yalnız
gösterilir — süreç doğmaz. Tetik Hyprland'in olay soketinden gelir; binds.lua
`hl.dsp.event("hypr-launcher <kip>")` yayar (claude-voice ile aynı düzen):

  apps   uygulamalar + açık pencereler + sistem komutları + hesap + web araması
  clip   pano geçmişi (cliphist)
  power  güç menüsü

Aynı kip açıkken tekrar gelirse kapanır; başka kip gelirse ona geçer.

DÖNÜŞÜM. Başlatıcının kendi zemini YOK. Açılırken waybar'a SIGRTMIN+10 atılır;
adanın "custom/morph" etiketi durum dosyasındaki kip adını (apps|clip|power)
metin olarak alır, waybar yaması adayı yay fiziğiyle tam bu pencerenin boyutuna
büyütür (waybar-island.patch, bar.nix drawer.morph, island.nix). Bu katman
adanın ÜSTÜNE, birebir aynı yere biner: üstteki şerit saydam — adanın saat ve
alan satırı görünür kalır — altında içerik ada büyürken solarak belirir.
Zemin, içbükey köşeler ve bulanıklık adanın kendisi. İçerik, adayla AYNI yay
parametreleriyle büyüyen bir kabın içinde: ada açılırken içerik ortadan açılır,
kapanırken birlikte toplanır (eskiden sırayla solup belirdiği için ada geçişte
bir an boş blok gibi görünüyordu).

Tam ekran pencere varsa waybar (top katmanı) onun ALTINDA kalır; o zaman bu
pencere adayı kendisi çizer (".solo": zemin + kendi saati).

Boyutlar ve renkler Nix'ten gelen JSON'da (--config); simge/yazı tipi kararları
style.css'te.
"""

import ast
import json
import math
import operator
import os
import re
import shlex
import signal
import socket
import subprocess
import sys
import time
import unicodedata

# GL: Vulkan yolu bütün aygıtları sayar ve NVIDIA ICD'sini yükler (dGPU uyanır).
# GTK ortamı başlatıcının kendisi için; açılan uygulamalara geçmez (CHILD_ENV).
os.environ.setdefault("GSK_RENDERER", "gl")

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")
from gi.repository import Gdk, Gio, GLib, Gtk, Pango  # noqa: E402
from gi.repository import Gtk4LayerShell as Layer  # noqa: E402

try:  # GLib 2.86+: Unix'e özgü API'ler ayrı ad alanında
    gi.require_version("GioUnix", "2.0")
    gi.require_version("GLibUnix", "2.0")
    from gi.repository import GioUnix, GLibUnix  # noqa: E402
    DesktopAppInfo, signal_add = GioUnix.DesktopAppInfo, GLibUnix.signal_add
except (ValueError, ImportError):
    DesktopAppInfo, signal_add = Gio.DesktopAppInfo, GLib.unix_signal_add

# Sarmalayıcının (Nix) koyduğu ve GTK'nın kendisi için olanlar çocuklara geçmez:
# LD_PRELOAD'lu bir layer-shell her açılan uygulamaya da yüklenirdi.
CHILD_ENV = {k: v for k, v in os.environ.items()
             if k not in ("LD_PRELOAD", "GI_TYPELIB_PATH", "GSK_RENDERER")}

STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "hypr-launcher")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")


def log(*a):
    print("hypr-launcher:", *a, file=sys.stderr, flush=True)


# ---- metin eşleme -------------------------------------------------------------

TR = str.maketrans({"ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ç": "c", "Ç": "c",
                    "ğ": "g", "Ğ": "g", "ö": "o", "Ö": "o", "ü": "u", "Ü": "u"})


def fold(s):
    """Küçük harf, Türkçe harfler ASCII'ye, aksanlar atılır: "Gör" ~ "gor"."""
    s = (s or "").translate(TR).lower()
    s = unicodedata.normalize("NFKD", s)
    return "".join(c for c in s if not unicodedata.combining(c))


def match(q, text):
    """0 = eşleşmedi. Tam > baştan > kelime başı > içinde > dağınık (fzf benzeri)."""
    if not text:
        return 0
    i = text.find(q)
    if i == 0:
        return 100 if len(text) == len(q) else 92 - min(len(text), 40) * 0.1
    if i > 0:
        return 80 if not text[i - 1].isalnum() else 62 - min(i, 20) * 0.3
    if len(q) < 2:
        return 0
    # Dağınık: her harf sırayla. Ardışık harf ve kelime başı ödüllü.
    pos, first, bonus, streak = 0, -1, 0.0, 0
    for ch in q:
        j = text.find(ch, pos)
        if j < 0:
            return 0
        if first < 0:
            first = j
        streak = streak + 1 if j == pos and pos > 0 else 0
        bonus += streak * 1.5
        if j == 0 or not text[j - 1].isalnum():
            bonus += 3
        pos = j + 1
    span = pos - first
    return min(48, 18 + 22 * len(q) / span + bonus)


# ---- hesap makinesi -----------------------------------------------------------

_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
        ast.Div: operator.truediv, ast.FloorDiv: operator.floordiv,
        ast.Mod: operator.mod, ast.Pow: operator.pow}
_FUNCS = {n: getattr(math, n) for n in (
    "sqrt", "sin", "cos", "tan", "asin", "acos", "atan", "log", "log2", "log10",
    "exp", "floor", "ceil", "radians", "degrees", "factorial")}
_FUNCS.update(abs=abs, round=round, kok=math.sqrt)
_CONSTS = {"pi": math.pi, "e": math.e, "tau": math.tau}


def _eval(node):
    if isinstance(node, ast.Expression):
        return _eval(node.body)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.BinOp) and type(node.op) in _OPS:
        a, b = _eval(node.left), _eval(node.right)
        if isinstance(node.op, ast.Pow) and (abs(b) > 1000 or abs(a) > 1e6 and b > 10):
            raise ValueError("çok büyük")
        return _OPS[type(node.op)](a, b)
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
        v = _eval(node.operand)
        return -v if isinstance(node.op, ast.USub) else v
    if isinstance(node, ast.Name) and node.id in _CONSTS:
        return _CONSTS[node.id]
    if (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
            and node.func.id in _FUNCS and not node.keywords):
        args = [_eval(a) for a in node.args]
        if node.func.id == "factorial" and args and args[0] > 500:
            raise ValueError("çok büyük")
        return _FUNCS[node.func.id](*args)
    raise ValueError("desteklenmeyen ifade")


def calculate(text):
    """İfade gibi görünüyorsa (sonuç, gösterim) döner, yoksa None."""
    s = text.strip()
    forced = s.startswith("=")
    s = s.lstrip("=").strip()
    if not s or not re.search(r"\d|pi|tau", s):
        return None
    if not forced and not re.search(r"[-+*/^%×÷()]|sqrt|kok|sin|cos|tan|log|exp", s):
        return None
    if not re.fullmatch(r"[\d\s.,+\-*/^%×÷()a-z_]+", s):
        return None
    comma = "," in s and "." not in s  # Türkçe ondalık: 3,5*2
    s = s.replace("×", "*").replace("÷", "/").replace("^", "**")
    if comma:
        s = s.replace(",", ".")
    try:
        v = _eval(ast.parse(s, mode="eval"))
    except Exception:
        return None
    if isinstance(v, float):
        if math.isnan(v) or math.isinf(v):
            return None
        if v.is_integer() and abs(v) < 1e15:
            v = int(v)
    out = str(v) if isinstance(v, int) else f"{v:.12g}"
    return out, out.replace(".", ",") if comma else out


# ---- Hyprland -----------------------------------------------------------------

def hypr_socket(name):
    return os.path.join(RUNTIME, "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"], name)


def hypr(cmd):
    """hyprctl'in yaptığının aynısı, süreç doğurmadan: istek soketi."""
    if "HYPRLAND_INSTANCE_SIGNATURE" not in os.environ:
        return ""
    try:
        with socket.socket(socket.AF_UNIX) as s:
            s.settimeout(1)
            s.connect(hypr_socket(".socket.sock"))
            s.sendall(cmd.encode())
            buf = b""
            while chunk := s.recv(65536):
                buf += chunk
        return buf.decode(errors="replace")
    except OSError as e:
        log("hyprland isteği başarısız:", cmd, e)
        return ""


def hypr_json(cmd):
    try:
        return json.loads(hypr("j/" + cmd))
    except ValueError:
        return None


# ---- waybar adası ------------------------------------------------------------

class Island:
    """Durum dosyası + sinyal: bar.nix "custom/morph" sınıfı → ada büyür/küçülür."""

    def __init__(self, state_file, signal_no):
        self.state = state_file
        self.sig = signal.SIGRTMIN + signal_no
        self.pid = None

    def _waybar(self):
        if self.pid and self._ours(self.pid):
            return self.pid
        self.pid = None
        # nixpkgs sarmalayıcısı yüzünden süreç adı ".waybar-wrapped".
        for d in os.listdir("/proc"):
            if d.isdigit() and self._ours(d):
                self.pid = int(d)
                break
        return self.pid

    @staticmethod
    def _ours(pid):
        """Bu oturumun waybar'ı mı: ad + aynı WAYLAND_DISPLAY (başka bir
        compositor örneğindeki waybar'a sinyal gitmesin)."""
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() not in (".waybar-wrapped", "waybar"):
                    return False
            with open(f"/proc/{pid}/environ", "rb") as f:
                env = f.read().split(b"\0")
        except OSError:
            return False
        want = ("WAYLAND_DISPLAY=" + os.environ.get("WAYLAND_DISPLAY", "wayland-0")).encode()
        return want in env

    def morph(self, mode):
        tmp = self.state + ".tmp"
        if mode:
            with open(tmp, "w") as f:
                # Metin = kip: waybar yaması boyutu buna göre seçer (drawer.morph).
                json.dump({"text": mode, "class": ["launcher", mode]}, f)
            os.replace(tmp, self.state)
        else:
            try:
                os.unlink(self.state)
            except FileNotFoundError:
                pass
        pid = self._waybar()
        if pid:
            try:
                os.kill(pid, self.sig)
            except OSError:
                self.pid = None


# ---- kullanım sıklığı ----------------------------------------------------------

class Frecency:
    """Her açılış +1; eski açılışlar 14 günlük yarı ömürle söner."""

    HALF_LIFE = 14 * 86400

    def __init__(self):
        self.path = os.path.join(STATE_DIR, "frecency.json")
        try:
            with open(self.path) as f:
                self.data = json.load(f)
        except (OSError, ValueError):
            self.data = {}

    def rank(self, key):
        e = self.data.get(key)
        if not e:
            return 0.0
        return e["r"] * 0.5 ** ((time.time() - e["t"]) / self.HALF_LIFE)

    def bonus(self, key):
        r = self.rank(key)
        return min(14.0, 6 * math.log2(1 + r)) if r else 0.0

    def bump(self, key):
        self.data[key] = {"r": self.rank(key) + 1, "t": time.time()}
        # Çok eskileri buda: dosya büyümesin.
        if len(self.data) > 400:
            for k in sorted(self.data, key=self.rank)[:100]:
                del self.data[k]
        try:
            os.makedirs(STATE_DIR, exist_ok=True)
            tmp = self.path + ".tmp"
            with open(tmp, "w") as f:
                json.dump(self.data, f)
            os.replace(tmp, self.path)
        except OSError as e:
            log("sıklık kaydedilemedi:", e)


# ---- sonuç ---------------------------------------------------------------------

class Item:
    __slots__ = ("title", "sub", "icon", "badge", "run", "key", "score",
                 "actions", "clip", "hint", "delay", "keep")

    def __init__(self, title, sub="", icon=None, badge=None, run=None, key=None,
                 score=0.0, actions=None, clip=None, hint="Aç", delay=False, keep=False):
        self.title = title
        self.sub = sub
        self.icon = icon        # Gio.Icon | simge adı | Gdk.Texture
        self.badge = badge      # None = renkli uygulama simgesi; aksi halde rozet rengi
        self.run = run          # çağrılabilir
        self.key = key          # sıklık anahtarı
        self.score = score
        self.actions = actions  # Tab ile açılan alt liste (uygulama eylemleri)
        self.clip = clip        # pano satırı (cliphist list çıktısı)
        self.hint = hint        # seçili satırın sağındaki eylem adı
        self.delay = delay      # True: içerik ekrandan silindikten sonra çalışsın
        self.keep = keep        # çalıştırınca başlatıcı açık kalsın (kip değişimi)


class App:
    __slots__ = ("info", "id", "name", "sub", "fields", "terminal")

    def __init__(self, info):
        self.info = info
        self.id = info.get_id() or ""
        self.name = info.get_display_name() or info.get_name() or self.id
        generic = info.get_generic_name() or ""
        desc = info.get_description() or ""
        self.sub = desc or generic
        exe = os.path.basename(info.get_executable() or "")
        kw = " ".join(info.get_keywords() or [])
        stem = self.id.removesuffix(".desktop").split(".")[-1]
        # (alan, ağırlık, dağınık eşleşmeye izin)
        self.fields = [(fold(self.name), 1.0, True), (fold(generic), 0.82, True),
                       (fold(kw), 0.78, False), (fold(exe), 0.72, True),
                       (fold(stem), 0.7, False), (fold(desc), 0.5, False)]
        self.terminal = info.get_boolean("Terminal")

    def score(self, q):
        best = 0.0
        for text, w, fuzzy in self.fields:
            if not text:
                continue
            s = match(q, text) if fuzzy or len(q) >= 3 else 0
            if not fuzzy and s < 80:
                s = 0  # açıklama/anahtar kelimede yalnız kelime başı: "eam" "streaming"i bulmasın
            best = max(best, s * w)
        return best


# ---- başlatıcı ----------------------------------------------------------------

class Launcher:
    def __init__(self, app, cfg):
        self.app = app
        self.cfg = cfg
        self.bin = cfg["bin"]
        self.island = Island(os.path.join(RUNTIME, "hypr-launcher.json"), cfg["signal"])
        self.freq = Frecency()
        self.apps = []
        self.app_by_class = {}
        self.mode = None          # açık kip; None = kapalı
        self.items = []
        self.sel = 0
        self.top = 0
        self.stack = []           # Tab ile alt listeye inildiğinde önceki durum
        self.windows = []
        self.clips = []
        self.thumbs = {}
        self.was_active = False
        self.pointer = None       # açılıştan sonraki ilk fare konumu (hover tetiği)
        self.closing = False
        # Yay durumu: kabın boyutu ve hızı (açık/kapalı arası canlandırma).
        self.cur = [0.0, 0.0]
        self.vel = [0.0, 0.0]
        self.goal = (0.0, 0.0)
        self.full_h = 1.0
        self.spring_k = self.spring_c = 0.0
        self.tick_id = 0
        self.last_t = None
        self.hold_until = 0
        self.on_faded = None      # içerik tamamen sönünce (kapanışta) bir kez

        self.load_apps()
        Gio.AppInfoMonitor.get().connect("changed", lambda *_: self.load_apps())
        self.build()
        # Önceki örnek açıkken öldüyse ada geri dönsün. YALNIZ bayat durum
        # dosyası varsa: oturum açılışında waybar sinyal işleyicisini kurmadan
        # gelen SIGRTMIN+10 onu öldürüyor (varsayılan eylem: sonlandır).
        if os.path.exists(self.island.state):
            self.island.morph(None)

    # ---- veri ----

    def load_apps(self):
        apps = []
        for info in Gio.AppInfo.get_all():
            if isinstance(info, DesktopAppInfo) and info.should_show():
                apps.append(App(info))
        apps.sort(key=lambda a: fold(a.name))
        self.apps = apps
        by_class = {}
        for a in apps:
            wm = a.info.get_startup_wm_class()
            if wm:
                by_class[wm.lower()] = a
            by_class.setdefault(a.id.removesuffix(".desktop").lower(), a)
        self.app_by_class = by_class

    def app_for_class(self, cls):
        c = (cls or "").lower()
        return self.app_by_class.get(c) or next(
            (a for k, a in self.app_by_class.items() if k.endswith("." + c) or c.endswith(k)), None)

    def load_windows(self):
        out = []
        for c in hypr_json("clients") or []:
            ws = c.get("workspace", {}).get("name", "")
            if not c.get("mapped") or c.get("hidden") or (ws.startswith("special:") and ws != "special:scratch"):
                continue
            out.append(c)
        out.sort(key=lambda c: c.get("focusHistoryID", 99))
        self.windows = out

    def load_clips(self):
        try:
            res = subprocess.run([self.bin["cliphist"], "list"], capture_output=True,
                                 env=CHILD_ENV, timeout=3)
            lines = res.stdout.decode(errors="replace").splitlines()
        except (OSError, subprocess.TimeoutExpired) as e:
            log("cliphist list:", e)
            lines = []
        self.clips = [ln for ln in lines if "\t" in ln][:500]

    # ---- arayüz ----

    def build(self):
        win = Gtk.Window(application=self.app, title="hypr-launcher")
        win.add_css_class("launcher")
        win.set_decorated(False)
        Layer.init_for_window(win)
        Layer.set_namespace(win, "hypr-launcher")
        Layer.set_layer(win, Layer.Layer.OVERLAY)
        Layer.set_anchor(win, Layer.Edge.TOP, True)
        Layer.set_margin(win, Layer.Edge.TOP, 0)
        Layer.set_exclusive_zone(win, -1)  # başka barların ayırdığı alanı yok say: tam üst kenar
        Layer.set_keyboard_mode(win, Layer.KeyboardMode.ON_DEMAND)
        self.win = win

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        root.add_css_class("root")
        win.set_child(root)
        self.root = root

        # Adanın saat satırının yeri. Normalde boş (waybar'ın satırı görünür);
        # tam ekranda waybar alttayken kendi saatini gösterir.
        head = Gtk.Box()
        head.add_css_class("head")
        head.set_size_request(-1, self.cfg["header"])
        self.clock = Gtk.Label(hexpand=True)
        self.clock.add_css_class("clock")
        self.clock.set_visible(False)
        head.append(self.clock)
        root.append(head)

        # İçerik adayla AYNI yayla açılan bir kabın içinde (waybar yamasıyla
        # aynı düzen): kap büyüdükçe içerik ortadan ve yukarıdan açılır, küçülünce
        # birlikte toplanır. Ada hiçbir an boş bir blok gibi görünmez.
        clip = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.EXTERNAL,
                                  vscrollbar_policy=Gtk.PolicyType.EXTERNAL,
                                  halign=Gtk.Align.CENTER, valign=Gtk.Align.START,
                                  propagate_natural_width=False, propagate_natural_height=False)
        clip.add_css_class("clip")
        clip.set_size_request(0, 0)
        hadj = clip.get_hadjustment()
        hadj.connect("changed", lambda a: a.set_value(math.floor((a.get_upper() - a.get_page_size()) / 2)))
        vadj = clip.get_vadjustment()
        vadj.connect("changed", lambda a: a.set_value(0))
        root.append(clip)
        self.clip = clip

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content.add_css_class("content")
        clip.set_child(content)
        self.content = content

        search = Gtk.Box(spacing=10)
        search.add_css_class("search")
        icon = Gtk.Image.new_from_icon_name("system-search-symbolic")
        icon.add_css_class("glass")
        search.append(icon)
        entry = Gtk.Text(hexpand=True)
        entry.connect("changed", lambda *_: self.refresh())
        search.append(entry)
        self.entry = entry
        self.chip = Gtk.Label(valign=Gtk.Align.CENTER)
        self.chip.add_css_class("chip")
        search.append(self.chip)
        content.append(search)

        self.caption = Gtk.Label(xalign=0)
        self.caption.add_css_class("caption")
        content.append(self.caption)

        rows_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, vexpand=True)
        rows_box.add_css_class("list")
        content.append(rows_box)
        self.rows = []
        for i in range(max(m["rows"] for m in self.cfg["modes"].values())):
            rows_box.append(self.make_row(i))

        scroll = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL)
        scroll.connect("scroll", self.on_scroll)
        rows_box.add_controller(scroll)

        self.footer = Gtk.Box()
        self.footer.add_css_class("footer")
        content.append(self.footer)

        keys = Gtk.EventControllerKey()
        keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self.on_key)
        win.add_controller(keys)

        motion = Gtk.EventControllerMotion()
        motion.connect("motion", self.on_motion)
        win.add_controller(motion)

        win.connect("notify::is-active", self.on_active)

    def make_row(self, i):
        row = Gtk.Box(spacing=12)
        row.add_css_class("row")
        row.set_size_request(-1, self.cfg["rowHeight"])
        holder = Gtk.Box(valign=Gtk.Align.CENTER, halign=Gtk.Align.CENTER)
        holder.add_css_class("icon")
        img = Gtk.Image()
        holder.append(img)
        row.append(holder)
        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER, hexpand=True)
        title = Gtk.Label(xalign=0, ellipsize=Pango.EllipsizeMode.END)
        title.add_css_class("title")
        sub = Gtk.Label(xalign=0, ellipsize=Pango.EllipsizeMode.END)
        sub.add_css_class("sub")
        texts.append(title)
        texts.append(sub)
        row.append(texts)
        hint = Gtk.Box(spacing=6, valign=Gtk.Align.CENTER)
        hint.add_css_class("hint")
        hint_label = Gtk.Label()
        hint_label.add_css_class("desc")
        hint.append(hint_label)
        key = Gtk.Label(label="↵")
        key.add_css_class("key")
        hint.append(key)
        row.append(hint)

        click = Gtk.GestureClick()
        click.connect("released", lambda g, n, x, y: self.click_row(i))
        row.add_controller(click)
        hover = Gtk.EventControllerMotion()
        hover.connect("motion", lambda c, x, y: self.hover_row(i))
        row.add_controller(hover)
        row.parts = (holder, img, title, sub, hint_label)
        self.rows.append(row)
        return row

    def set_footer(self, pairs):
        child = self.footer.get_first_child()
        while child:
            nxt = child.get_next_sibling()
            self.footer.remove(child)
            child = nxt
        for key, desc in pairs:
            k = Gtk.Label(label=key)
            k.add_css_class("key")
            self.footer.append(k)
            d = Gtk.Label(label=desc)
            d.add_css_class("desc")
            self.footer.append(d)

    # ---- aç / kapa ----

    def request(self, mode):
        if mode not in self.cfg["modes"]:
            log("bilinmeyen kip:", mode)
            return
        if self.mode == mode and not self.closing:
            self.close()
        elif self.mode and not self.closing:
            self.open(mode, switch=True)
        else:
            self.open(mode)

    def open(self, mode, switch=False):
        self.closing = False
        self.on_faded = None
        self.mode = mode
        self.stack = []
        m = self.cfg["modes"][mode]
        for c in self.cfg["modes"]:
            self.root.remove_css_class(c)
        self.root.add_css_class(mode)
        self.root.set_size_request(m["width"], m["height"])
        self.win.set_default_size(m["width"], m["height"])
        self.full_h = m["height"] - self.cfg["header"]
        self.content.set_size_request(m["width"], self.full_h)

        if mode == "apps":
            self.load_windows()
        elif mode == "clip":
            self.load_clips()

        # Tam ekranda waybar fullscreen pencerenin altında kalır → adayı kendin çiz.
        ws = hypr_json("activeworkspace") or {}
        solo = bool(ws.get("hasfullscreen"))
        self.root.set_css_classes([c for c in self.root.get_css_classes() if c != "solo"]
                                  + (["solo"] if solo else []))
        self.clock.set_visible(solo)
        if solo:
            self.clock.set_label(time.strftime("%H:%M"))

        self.entry.set_placeholder_text(m["placeholder"])
        self.chip.set_label(m["chip"])
        self.set_footer([tuple(p) for p in m["footer"]])
        self.entry.set_text("")
        self.refresh()

        self.island.morph(mode)
        self.was_active = False
        self.pointer = None
        if not switch and not self.win.get_visible():
            # Kap kapalı adanın genişliğinden başlar. Waybar'ın sinyali işleyip
            # kendi yayını başlatması birkaç ms sürer: içerik adanın önüne
            # geçmesin diye yay o kadar geç başlar.
            self.cur = [float(self.cfg["restWidth"]), 0.0]
            self.vel = [0.0, 0.0]
            self.hold_until = GLib.get_monotonic_time() + self.cfg["leadMs"] * 1000
            self.apply_size()
            self.win.present()
        self.entry.grab_focus()
        self.animate((m["width"], self.full_h), "open")

    def close(self, then=None, after_fade=False):
        if not self.mode or self.closing:
            return
        self.closing = True
        # Ada ile içerik BİRLİKTE toplanır: aynı anda, aynı yayla.
        self.island.morph(None)
        if then and not after_fade:
            then()
        # Ekran görüntüsü, kilit gibi eylemler içerik ekrandan silinince.
        self.on_faded = then if after_fade else None
        self.animate((float(self.cfg["restWidth"]), 0.0), "close")

    # ---- yay ----

    def animate(self, goal, kind):
        response, damping = self.cfg["spring"][kind]
        if kind == "close":
            # Ada sinyali birkaç ms geç alır; içerik onun önünde toplansın ki
            # daralan adanın kenarından taşmasın.
            response *= self.cfg["closeLead"]
        w = 2 * math.pi / response
        self.spring_k, self.spring_c = w * w, 2 * damping * w
        self.goal = goal
        if not self.tick_id:
            self.last_t = None
            self.tick_id = self.root.add_tick_callback(self.on_tick)

    def apply_size(self):
        w = 2 * math.ceil(max(0.0, self.cur[0]) / 2)  # çift: ortalama yarım piksel kaymasın
        h = round(max(0.0, self.cur[1]))
        self.clip.set_size_request(w, h)
        # Saydamlık boyuta bağlı (waybar yamasıyla aynı eğri): kapanışta da
        # içerik adayla birlikte küçülür, en sonda söner.
        frac = self.cur[1] / self.full_h if self.full_h > 1 else 0.0
        t = min(1.0, max(0.0, (frac - 0.06) / 0.40))
        o = t * t * (3 - 2 * t)
        self.clip.set_opacity(o)
        return o

    def on_tick(self, widget, clock):
        now = clock.get_frame_time()
        if now < self.hold_until:
            return GLib.SOURCE_CONTINUE
        dt = 1 / 120 if self.last_t is None else min(0.05, (now - self.last_t) / 1e6)
        self.last_t = now
        k, c = self.spring_k, self.spring_c
        left = dt
        while left > 1e-9:  # yarı örtük Euler, 1 ms adım
            h = min(0.001, left)
            for i in (0, 1):
                self.vel[i] += (-k * (self.cur[i] - self.goal[i]) - c * self.vel[i]) * h
                self.cur[i] += self.vel[i] * h
            left -= h
        settled = all(abs(self.cur[i] - self.goal[i]) < 0.3 and abs(self.vel[i]) < 3 for i in (0, 1))
        if settled:
            self.cur = list(self.goal)
            self.vel = [0.0, 0.0]
        o = self.apply_size()

        if self.closing:
            if o <= 0.001 and self.on_faded:
                run, self.on_faded = self.on_faded, None
                GLib.timeout_add(40, lambda: run() and False)  # son kare ekrandan silinsin
            if self.cur[1] < 1.0:
                self.win.set_visible(False)
                self.mode = None
                self.closing = False
                self.cur, self.vel = [0.0, 0.0], [0.0, 0.0]
                if self.on_faded:
                    run, self.on_faded = self.on_faded, None
                    GLib.timeout_add(40, lambda: run() and False)
                self.tick_id = 0
                return GLib.SOURCE_REMOVE
        if settled:
            self.tick_id = 0
            return GLib.SOURCE_REMOVE
        return GLib.SOURCE_CONTINUE

    def on_active(self, win, _pspec):
        if win.is_active():
            self.was_active = True
        elif self.was_active and self.mode and not self.closing and self.cfg.get("closeOnBlur", True):
            self.close()  # başka yere tıklandı

    # ---- sonuçlar ----

    def refresh(self):
        q_raw = self.entry.get_text()
        q = fold(q_raw.strip())
        if self.stack:
            items = self.stack[-1][0]
            items = [it for it in items if not q or match(q, fold(it.title))]
            caption = self.stack[-1][1]
        elif self.mode == "apps":
            items, caption = self.search_apps(q_raw, q)
        elif self.mode == "clip":
            items, caption = self.search_clips(q)
        else:
            items, caption = self.search_power(q)
        self.items = items
        self.caption.set_label(caption)
        self.sel = 0
        self.top = 0
        self.render()

    def search_apps(self, raw, q):
        if raw.startswith(">"):
            cmd = raw[1:].strip()
            return ([Item(cmd or "Komut yaz…", "Terminalde çalıştır · ghostty",
                          "utilities-terminal-symbolic", "accent",
                          run=(lambda: self.spawn([self.bin["uwsmApp"], "--", "ghostty", "-e",
                                                   "sh", "-c", cmd])) if cmd else None,
                          hint="Çalıştır")], "Komut")
        if not q:
            ranked = sorted(self.apps, key=lambda a: -self.freq.rank("app:" + a.id))
            recent = [a for a in ranked if self.freq.rank("app:" + a.id) > 0.05][:7]
            rest = [a for a in self.apps if a not in recent]
            items = [self.app_item(a) for a in recent + rest]
            return items, "Sık kullanılanlar" if recent else "Uygulamalar"

        results = []
        calc = calculate(raw)
        if calc:
            value, shown = calc
            results.append(Item(shown, f"{raw.strip().lstrip('=').strip()} · Enter: panoya kopyala",
                                "accessories-calculator-symbolic", "green",
                                run=lambda: self.copy(value), score=1000, hint="Kopyala"))

        for a in self.apps:
            s = a.score(q)
            if s:
                it = self.app_item(a)
                it.score = s + self.freq.bonus("app:" + a.id)
                results.append(it)

        for c in self.windows:
            title, cls = c.get("title", ""), c.get("class", "")
            s = max(match(q, fold(title)), match(q, fold(cls)) * 0.9)
            if s:
                a = self.app_for_class(cls)
                ws = c.get("workspace", {}).get("name", "")
                addr = c.get("address")
                results.append(Item(
                    title or cls, f"Açık pencere · {a.name if a else cls} · alan {ws.replace('special:', '')}",
                    a.info.get_icon() if a else "window-new-symbolic", None if a else "accent",
                    run=lambda addr=addr: hypr(f'dispatch hl.dsp.focus({{ window = "address:{addr}" }})'),
                    score=s * 0.92 - 2, hint="Geç"))

        for cmd in self.commands():
            s = max(match(q, fold(cmd.title)), max((match(q, k) for k in cmd.key), default=0) * 0.9)
            if s:
                cmd.score = s * 0.9
                results.append(cmd)

        results.sort(key=lambda it: -it.score)
        results.append(Item(f"Web'de ara: “{raw.strip()}”", "Varsayılan arama motoru · Zen",
                            "web-browser-symbolic", "blue",
                            run=lambda: self.spawn([self.bin["uwsmApp"], "--", "zen-beta", "--search", raw.strip()]),
                            hint="Ara"))
        n = len(results) - 1 - (1 if calc else 0)
        if n:
            return results, f"{n} sonuç"
        return results, "Hesap" if calc else "Eşleşen sonuç yok"

    def app_item(self, a):
        actions = None
        names = a.info.list_actions()
        if names:
            actions = [Item(a.info.get_action_name(n), a.name, a.info.get_icon(),
                            run=lambda n=n, a=a: self.launch(a, n), hint="Aç") for n in names]
        sub = a.sub
        if actions:
            sub = (sub + " · " if sub else "") + f"{len(actions)} eylem"
        return Item(a.name, sub, a.info.get_icon(), run=lambda: self.launch(a),
                    key="app:" + a.id, actions=actions)

    def commands(self):
        b = self.bin
        sh = self.spawn
        return [
            Item("Pano geçmişi", "Kopyalananlar · SUPER+V", "edit-paste-symbolic", "accent",
                 run=lambda: self.open("clip", switch=True), key=["pano", "clipboard", "kopyala"],
                 hint="Aç", keep=True),
            Item("Güç menüsü", "Kilitle, uyku, yeniden başlat · SUPER+Esc", "system-shutdown-symbolic", "red",
                 run=lambda: self.open("power", switch=True), key=["guc", "power"], hint="Aç", keep=True),
            Item("Rahatsız etme", "Bildirimleri sustur / aç · SUPER+N", "notifications-disabled-symbolic",
                 "accent", run=lambda: sh([b["dnd"], "toggle"]), key=["dnd", "bildirim", "sessiz"],
                 hint="Değiştir"),
            Item("Bildirimleri temizle", "Ekrandakileri kapat", "edit-clear-all-symbolic", "accent",
                 run=lambda: sh([b["makoctl"], "dismiss", "--all"]), key=["notification", "clear"],
                 hint="Temizle"),
            Item("Gece ışığı", "Aç / kapat · SUPER+Shift+N", "night-light-symbolic", "yellow",
                 run=lambda: sh([b["nightLight"]]), key=["night", "sicaklik", "mavi isik"], hint="Değiştir"),
            Item("Ekran görüntüsü", "Bölge seç · panoya ve ~/Pictures/Screenshots", "camera-photo-symbolic",
                 "accent", run=lambda: sh([b["screenshot"], "area"]), key=["screenshot", "goruntu", "ss"],
                 hint="Çek", delay=True),
            Item("Ekran görüntüsü · tüm ekran", "Panoya ve ~/Pictures/Screenshots", "camera-photo-symbolic",
                 "accent", run=lambda: sh([b["screenshot"], "screen"]), key=["screenshot", "tam ekran"],
                 hint="Çek", delay=True),
            Item("Ekran görüntüsü · işaretle", "Bölge seç, satty ile düzenle", "camera-photo-symbolic",
                 "accent", run=lambda: sh([b["screenshot"], "edit"]), key=["screenshot", "satty", "duzenle"],
                 hint="Çek", delay=True),
            Item("Renk seçici", "Ekrandan renk al → pano (hex)", "color-select-symbolic", "accent",
                 run=lambda: sh(b["colorPicker"]), key=["color", "renk", "hex", "picker"], hint="Seç",
                 delay=True),
        ] + self.power_items()

    def power_items(self):
        sc = self.bin["systemctl"]
        return [
            Item("Kilitle", "hyprlock · SUPER+L", "system-lock-screen-symbolic", "accent",
                 run=lambda: self.spawn([self.bin["loginctl"], "lock-session"]), key=["lock"],
                 hint="Kilitle", delay=True),
            Item("Uyku", "Bellekte askıya al", "weather-clear-night-symbolic", "blue",
                 run=lambda: self.spawn([sc, "suspend"]), key=["suspend", "sleep", "askiya"],
                 hint="Uyut", delay=True),
            Item("Oturumu kapat", "Hyprland oturumu sonlanır", "system-log-out-symbolic", "yellow",
                 run=lambda: self.spawn([self.bin["uwsm"], "stop"]), key=["logout", "cikis"],
                 hint="Çık", delay=True),
            Item("Yeniden başlat", "Sistem yeniden açılır", "system-reboot-symbolic", "orange",
                 run=lambda: self.spawn([sc, "reboot"]), key=["reboot", "restart"],
                 hint="Başlat", delay=True),
            Item("Kapat", "Bilgisayarı kapat", "system-shutdown-symbolic", "red",
                 run=lambda: self.spawn([sc, "poweroff"]), key=["shutdown", "poweroff", "kapat"],
                 hint="Kapat", delay=True),
            Item("UEFI ayarlarına yeniden başlat", "Açılışta firmware kurulumuna gir",
                 "preferences-system-symbolic", "orange",
                 run=lambda: self.spawn([sc, "reboot", "--firmware-setup"]), key=["uefi", "bios", "firmware"],
                 hint="Başlat", delay=True),
        ]

    def search_power(self, q):
        items = self.power_items()
        if not q:
            return items[:5], "Güç"
        keyed = []
        for it in items:
            s = max(match(q, fold(it.title)), max((match(q, k) for k in it.key), default=0) * 0.9)
            if s:
                it.score = s
                keyed.append(it)
        keyed.sort(key=lambda it: -it.score)
        return keyed, "Güç"

    def search_clips(self, q):
        items = []
        for line in self.clips:
            cid, _, preview = line.partition("\t")
            m = re.match(r"\[\[ binary data (.+?) (\w+) (\d+x\d+) \]\]", preview)
            if m:
                size, fmt, dim = m.groups()
                title, sub, icon = "Görsel", f"{fmt} · {dim.replace('x', '×')} · {size}", "image-x-generic-symbolic"
                text = fold(f"gorsel resim image {fmt}")
            else:
                title = " ".join(preview.split())
                # cliphist önizlemeyi ~100 karakterde keser: uzunluk yazılmaz.
                sub, icon, text = "Metin", "text-x-generic-symbolic", fold(title)
            if q and not match(q, text):
                continue
            items.append(Item(title or "(boş)", sub, icon, "accent",
                              run=lambda ln=line: self.paste(ln), clip=line, hint="Kopyala"))
        if not self.clips:
            items = [Item("Pano geçmişi boş", "Kopyaladıkların burada birikir", "edit-paste-symbolic", "accent")]
        return items, f"Pano · {len(self.clips)} kayıt"

    # ---- çizim ----

    def visible_rows(self):
        return self.cfg["modes"][self.mode]["rows"] if self.mode else len(self.rows)

    def render(self):
        n = self.visible_rows()
        for i, row in enumerate(self.rows):
            idx = self.top + i
            if i >= n or idx >= len(self.items):
                row.set_visible(False)
                continue
            it = self.items[idx]
            holder, img, title, sub, hint = row.parts
            holder.set_css_classes(["icon"] + (["badge", it.badge] if it.badge else []))
            if isinstance(it.icon, Gio.Icon):
                img.set_from_gicon(it.icon)
            elif isinstance(it.icon, Gdk.Paintable):
                img.set_from_paintable(it.icon)
            else:
                img.set_from_icon_name(it.icon or "application-x-executable")
            img.set_pixel_size(self.cfg["iconSize"] if not it.badge else 18)
            title.set_label(it.title)
            sub.set_label(it.sub)
            sub.set_visible(bool(it.sub))
            hint.set_label(it.hint)
            row.set_css_classes(["row"] + (["selected"] if idx == self.sel else [])
                                + ([] if it.run else ["inert"]))
            row.set_visible(True)
            if it.clip and it.icon == "image-x-generic-symbolic":
                self.thumbnail(it, idx)

    def thumbnail(self, it, idx):
        """Görsel kaydın küçük resmi: yalnız görünen satırlar için, önbellekli."""
        cid = it.clip.partition("\t")[0]
        if cid in self.thumbs:
            if self.thumbs[cid]:
                it.icon, it.badge = self.thumbs[cid], None
                self.render_row(idx)
            return
        self.thumbs[cid] = None
        proc = Gio.Subprocess.new([self.bin["cliphist"], "decode"],
                                  Gio.SubprocessFlags.STDIN_PIPE | Gio.SubprocessFlags.STDOUT_PIPE)

        def done(p, res):
            try:
                _, out, _ = p.communicate_finish(res)
                tex = Gdk.Texture.new_from_bytes(out)
            except GLib.Error:
                return
            self.thumbs[cid] = tex
            for j, other in enumerate(self.items):
                if other.clip == it.clip:
                    other.icon, other.badge = tex, None
                    self.render_row(j)
        proc.communicate_async(GLib.Bytes.new((it.clip + "\n").encode()), None, done)

    def render_row(self, idx):
        i = idx - self.top
        if 0 <= i < self.visible_rows() and self.mode:
            holder, img, *_ = self.rows[i].parts
            it = self.items[idx]
            holder.set_css_classes(["icon"] + (["badge", it.badge] if it.badge else []))
            img.set_from_paintable(it.icon)
            img.set_pixel_size(self.cfg["iconSize"])

    def move(self, d):
        if not self.items:
            return
        self.sel = max(0, min(len(self.items) - 1, self.sel + d))
        n = self.visible_rows()
        if self.sel < self.top:
            self.top = self.sel
        elif self.sel >= self.top + n:
            self.top = self.sel - n + 1
        self.render()

    # ---- girdi ----

    def on_key(self, ctl, keyval, keycode, state):
        ctrl = state & Gdk.ModifierType.CONTROL_MASK
        shift = state & Gdk.ModifierType.SHIFT_MASK
        k = Gdk.keyval_name(keyval) or ""
        n = self.visible_rows()
        if k == "Escape":
            if self.stack:
                self.stack.pop()
                self.entry.set_text("")
                self.refresh()
            else:
                self.close()
            return True
        if k in ("Down",) or (ctrl and k in ("n", "j")):
            self.move(1)
        elif k in ("Up",) or (ctrl and k in ("p", "k")):
            self.move(-1)
        elif k == "Page_Down":
            self.move(n)
        elif k == "Page_Up":
            self.move(-n)
        elif k in ("Tab", "ISO_Left_Tab"):
            if shift or k == "ISO_Left_Tab":
                if self.stack:
                    self.stack.pop()
                    self.entry.set_text("")
                    self.refresh()
            else:
                self.enter_actions()
        elif k == "Delete" and shift and self.mode == "clip":
            self.delete_clip()
        elif k in ("Return", "KP_Enter"):
            self.activate()
        else:
            return False
        return True

    def on_scroll(self, ctl, dx, dy):
        self.move(1 if dy > 0 else -1)
        return True

    def on_motion(self, ctl, x, y):
        if self.pointer is None:
            self.pointer = (x, y)
        elif abs(x - self.pointer[0]) + abs(y - self.pointer[1]) > 3:
            self.pointer = (-1e9, -1e9)  # gerçekten oynadı: artık hover seçer

    def hover_row(self, i):
        # Açılışta imleç zaten listenin üstündeyse seçimi çalmasın: önce oynamalı.
        if self.pointer and self.pointer[0] == -1e9 and self.top + i != self.sel:
            self.sel = self.top + i
            self.render()

    def click_row(self, i):
        idx = self.top + i
        if idx < len(self.items):
            self.sel = idx
            self.activate()

    def enter_actions(self):
        if not self.items:
            return
        it = self.items[self.sel]
        if it.actions:
            self.stack.append((it.actions, f"{it.title} · eylemler"))
            self.entry.set_text("")
            self.refresh()

    def activate(self):
        if not self.items or self.closing:
            return
        it = self.items[min(self.sel, len(self.items) - 1)]
        if not it.run:
            return
        if isinstance(it.key, str):
            self.freq.bump(it.key)
        if it.keep:
            it.run()
        else:
            self.close(then=it.run, after_fade=it.delay)

    # ---- eylemler ----

    def spawn(self, argv):
        if isinstance(argv, str):
            argv = shlex.split(argv)
        try:
            subprocess.Popen(argv, env=CHILD_ENV, cwd=os.path.expanduser("~"),
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as e:
            log("başlatılamadı:", argv, e)

    def launch(self, a, action=None):
        uwsm = self.bin["uwsmApp"]
        if a.terminal and not action:
            # uwsm'in -T yolu xdg-terminal-exec istiyor (kurulu değil): ghostty -e.
            cmd = [t for t in shlex.split(a.info.get_commandline() or "") if not t.startswith("%")]
            self.spawn([uwsm, "--", "ghostty", "-e", *cmd])
        else:
            self.spawn([uwsm, "--", a.id + (":" + action if action else "")])

    def copy(self, text):
        try:
            p = subprocess.Popen([self.bin["wlCopy"]], stdin=subprocess.PIPE, env=CHILD_ENV,
                                 start_new_session=True)
            p.stdin.write(text.encode())
            p.stdin.close()
        except OSError as e:
            log("wl-copy:", e)

    def paste(self, line):
        try:
            dec = subprocess.Popen([self.bin["cliphist"], "decode"], stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, env=CHILD_ENV)
            subprocess.Popen([self.bin["wlCopy"]], stdin=dec.stdout, env=CHILD_ENV,
                             start_new_session=True)
            dec.stdout.close()
            dec.stdin.write((line + "\n").encode())
            dec.stdin.close()
        except OSError as e:
            log("pano:", e)

    def delete_clip(self):
        if not self.items or not self.items[self.sel].clip:
            return
        line = self.items[self.sel].clip
        subprocess.run([self.bin["cliphist"], "delete"], input=(line + "\n").encode(), env=CHILD_ENV)
        self.clips = [c for c in self.clips if c != line]
        sel = self.sel
        self.refresh()
        self.move(min(sel, len(self.items) - 1))


# ---- olaylar ------------------------------------------------------------------

def listen(launcher):
    """Soket2: binds.lua'nın yaydığı custom>>hypr-launcher <kip>."""
    if "HYPRLAND_INSTANCE_SIGNATURE" not in os.environ:
        log("Hyprland dışında: yalnız D-Bus eylemiyle açılır")
        return None
    s = socket.socket(socket.AF_UNIX)
    s.connect(hypr_socket(".socket2.sock"))
    s.setblocking(False)
    buf = [b""]

    def on_data(fd, cond):
        try:
            chunk = s.recv(65536)
        except BlockingIOError:
            return GLib.SOURCE_CONTINUE
        if not chunk:
            log("Hyprland olay soketi kapandı")
            launcher.island.morph(None)
            os._exit(1)
        buf[0] += chunk
        *lines, buf[0] = buf[0].split(b"\n")
        for line in lines:
            if line.startswith(b"custom>>hypr-launcher"):
                parts = line.decode(errors="replace").split()
                launcher.request(parts[1] if len(parts) > 1 else "apps")
        return GLib.SOURCE_CONTINUE

    GLib.io_add_watch(s.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP, on_data)
    return s


def main():
    cfg_path = sys.argv[sys.argv.index("--config") + 1]
    with open(cfg_path) as f:
        cfg = json.load(f)

    app = Gtk.Application(application_id=cfg.get("appId", "local.hypr.launcher"),
                          flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
    state = {}

    def startup(app):
        settings = Gtk.Settings.get_default()
        settings.set_property("gtk-icon-theme-name", cfg.get("iconTheme", "Adwaita"))
        provider = Gtk.CssProvider()
        provider.load_from_path(cfg["css"])
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        app.hold()
        launcher = Launcher(app, cfg)
        state["launcher"] = launcher
        state["sock"] = listen(launcher)
        # İkinci giriş: D-Bus eylemi (Hyprland dışından, betiklerden):
        #   gapplication action local.hypr.launcher open "'apps'"
        action = Gio.SimpleAction.new("open", GLib.VariantType.new("s"))
        action.connect("activate", lambda a, v: launcher.request(v.get_string()))
        app.add_action(action)
        # Pencereyi bir kez gerçekleştir (realize): ilk açılışta GL bağlamı, yazı
        # tipi ve simge önbelleği hazır olsun — ilk SUPER+Space de anında açılsın.
        launcher.win.realize()

    def quit_(*_):
        if "launcher" in state:
            state["launcher"].island.morph(None)
        app.quit()
        return GLib.SOURCE_REMOVE

    app.connect("startup", startup)
    app.connect("activate", lambda *_: None)
    signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, quit_)
    signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, quit_)
    sys.exit(app.run([sys.argv[0]]))


if __name__ == "__main__":
    main()
