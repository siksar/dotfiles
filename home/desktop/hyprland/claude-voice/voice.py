# claude-voice — Copilot tuşunun sesli asistanı (Hyprland), arka plan servisi.
#
#   claude-voice --daemon   systemd kullanıcı servisi (session.nix): Hyprland
#                           oturumuyla açılır, Chromium'u gizli alanda hazır tutar.
#   claude-voice            aç/kapa — tuşla aynı işi yapar (hyprctl eval); elle
#                           denemek için. Tuş bunu ÇAĞIRMAZ.
#
# Tuşa basınca hiçbir süreç doğmaz: binds.lua doğrudan claude_voice_toggle()'ı
# (lua/voice.lua) çağırır, animasyon o karede başlar ve soket2'ye olay yayılır.
# Servis olayı duyup sesli modu açar/kapatır. Servis yokken basılırsa Lua onu
# başlatır ve hap doğunca gösterir; servis hazır olunca hap görünürse sesli modu
# kendisi açar.
#
# Servisin işleri:
#   - Chromium'u başlatmak (ayrı profil, --app=claude.ai/new). Pencereleri
#     rules.lua gizli alanda doğurur. Chromium kapanırsa servis de çıkar,
#     systemd yeniden başlatır.
#   - session.js'i sayfaya enjekte etmek (CDP): durum, sohbet penceresi, karar.
#   - custom>>claude-voice show|hide → sesli modu aç/kapat (CDP gerçek tıklama).
#   - Sayfanın sohbet penceresi istekleri (CDP binding) → claude_voice_chat().
#   - Hap genişliği değişince (CDP binding) → claude_voice_width(): pencere
#     hapla birlikte büyür/küçülür.
#   - Hap penceresi kapanırsa (ör. elle kapatıldı) hemen çıkmak: systemd
#     yeniden başlatır, tuş yeni pencereyi gösterir.
#
# Neden CDP: claude.ai'de sesli modu başlatan URL parametresi ya da klavye
# kısayolu yok; JS'ten .click() de yetmiyor (sayfa güvenilir kullanıcı hareketi
# istiyor). Input.dispatchMouseEvent tarayıcı düzeyinde gerçek tıklama üretir.
# Port yalnız 127.0.0.1'e bağlı ve yalnız bu profile ait.
#
# Claude Desktop (Electron) kullanılamadı: --remote-debugging-port'u kendisi
# reddediyor, Quick Entry pop-up'ı da kodda yalnız macOS'a açık.
import fcntl
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.request

import websocket

CHROMIUM = "@chromium@"
EXTENSION = "@extension@"
SESSION_JS = @session_js@
PROFILE = os.path.join(
    os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "claude-voice", "chromium"
)
PORT = 9333
# Chromium Wayland'de app_id'yi --app adresinden türetir (--class yok sayılır):
# adres değişirse sınıf da değişir, rules.lua ve lua/voice.lua'daki eşleşme de.
# Sohbet penceresi aynı sınıfta; ilk başlığı "about:blank" olduğundan ayrılır.
URL = "https://claude.ai/new"
CLASS = "chrome-claude.ai__new-Default"
CHAT_TITLE = "about:blank"
# Başka bir örnek çalışırken verilen çıkış kodu; session.nix RestartPreventExitStatus.
ALONE = 75
# Pencere zemini = panel.css'teki kutu rengi. Chromium saydam pencere çizmiyor;
# sayfanın varsayılan zemini (#121212) boyutlandırma sırasında geç kalan
# karelerde görünmesin diye kutuyla aynı renge çekilir.
BOX_RGB = {"r": 32, "g": 32, "b": 31, "a": 1}
# Pencere genişliği sınırları (hap 48…110 + 68): sayfadan gelen değer süzülür.
WIDTH_MIN, WIDTH_MAX = 100, 240


def log(*a):
    print("claude-voice:", *a, file=sys.stderr, flush=True)


def hypr(*args):
    out = subprocess.run(["hyprctl", "-j", *args], capture_output=True, text=True).stdout
    return json.loads(out) if out.strip() else None


def pill():
    return next((c for c in hypr("clients") or []
                 if c.get("class") == CLASS and c.get("initialTitle") != CHAT_TITLE), None)


def wait(fn, timeout, step=0.2):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        v = fn()
        if v:
            return v
        time.sleep(step)
    return None


# ---- sayfa (CDP) ----------------------------------------------------------

class Page:
    def __init__(self, timeout=20, step=0.2):
        target = wait(self._target, timeout, step)
        if not target:
            raise RuntimeError("claude.ai sekmesi bulunamadı")
        self.ws = websocket.create_connection(target["webSocketDebuggerUrl"], timeout=15, suppress_origin=True)
        self.n = 0

    @staticmethod
    def _target():
        try:
            targets = json.load(urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json", timeout=1))
        except OSError:
            return None
        # Uygulama arka planda başka claude.ai sayfaları da açabiliyor (artifact
        # önizlemesi); sohbet penceresi about:blank. Yalnız asıl sayfa.
        for t in targets:
            if t["type"] == "page" and t["url"].startswith("https://claude.ai/") and "/artifact/" not in t["url"]:
                return t
        return None

    def call(self, method, **params):
        self.n += 1
        self.ws.send(json.dumps({"id": self.n, "method": method, "params": params}))
        while True:
            r = json.loads(self.ws.recv())
            if r.get("id") == self.n:
                return r.get("result", {})

    def js(self, expr):
        return self.call("Runtime.evaluate", expression=expr, returnByValue=True)["result"].get("value")

    def click(self, finder, timeout=15, alive=lambda: True):
        """finder: tıklanacak öğenin merkezini {x,y} döndüren JS ifadesi."""
        pos = wait(lambda: (not alive()) or self.js(finder), timeout)
        if not isinstance(pos, dict):
            return False
        for kind in ("mousePressed", "mouseReleased"):
            self.call("Input.dispatchMouseEvent", type=kind, x=pos["x"], y=pos["y"], button="left", clickCount=1)
        return True

    def close(self):
        try:
            self.ws.close()
        except websocket.WebSocketException:
            pass


def center(selector_js):
    return (
        "(() => { const b = " + selector_js + "; if (!b) return null;"
        " const r = b.getBoundingClientRect(); if (!r.width) return null;"
        " return {x: r.x + r.width / 2, y: r.y + r.height / 2}; })()"
    )


# Sesli mod açıkken kutuda "Stop" düğmesi (button.h-8) var. Görselleştirici bunun
# yerine geçmez: oturum bittikten sonra da DOM'da kalıyor.
STOP_BUTTON = "document.querySelector('fieldset .gap-1.shrink-0 > button.h-8')"
VOICE_ON = "!!" + STOP_BUTTON
START = center(
    "['Use voice mode', 'Voice mode', 'Start voice mode']"
    ".map(l => document.querySelector(`button[aria-label=\"${l}\"]`)).find(Boolean)"
)
STOP = center(STOP_BUTTON)


# ---- sesli mod --------------------------------------------------------------
# İstekler sıraya girer, son istek kazanır: hızlı aç-kapa-aç basışlarında yarım
# kalan başlatma, yeni istek gelince bırakılır.

class Voice:
    def __init__(self):
        self.want = None
        self.cond = threading.Condition()
        threading.Thread(target=self._run, daemon=True).start()

    def request(self, want):
        with self.cond:
            self.want = want
            self.cond.notify()

    def _run(self):
        while True:
            with self.cond:
                while self.want is None:
                    self.cond.wait()
                want, self.want = self.want, None
            try:
                if want == "show":
                    self._start()
                elif want == "hide":
                    self._stop()
            except (RuntimeError, OSError, websocket.WebSocketException) as e:
                log(want, "başarısız:", e)

    def _alive(self):
        return self.want is None  # yeni istek gelmediyse süren iş geçerli

    def _start(self):
        p = Page()
        try:
            p.call("Browser.grantPermissions", origin="https://claude.ai", permissions=["audioCapture"])
            p.js("window.__claudeVoiceReset && window.__claudeVoiceReset()")
            if p.js(VOICE_ON):
                return
            # Her açılış yeni sohbet: önceki sesli oturumun sohbetine eklenmesin.
            if p.js("location.pathname") != "/new":
                p.call("Page.navigate", url=URL)
                time.sleep(1)
            # Düğme, sayfa hidrate olmadan DOM'a düşüyor ve o anki tıklama boşa
            # gidiyor: sesli mod açılana dek birkaç kez dene.
            for _ in range(6):
                if not self._alive():
                    return
                if p.click(START, alive=self._alive) and wait(lambda: (not self._alive()) or p.js(VOICE_ON), 2.5):
                    return
        finally:
            p.close()

    def _stop(self):
        p = Page(timeout=3)
        try:
            if p.js(VOICE_ON):
                p.click(STOP, timeout=3)
            p.js("window.__claudeVoiceCollapsed && window.__claudeVoiceCollapsed()")
        finally:
            p.close()


# ---- servis ------------------------------------------------------------------

def hypr_events(voice):
    """Hyprland soket2: tuşun yaydığı custom>>claude-voice show|hide."""
    path = os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr", os.environ["HYPRLAND_INSTANCE_SIGNATURE"], ".socket2.sock")
    s = socket.socket(socket.AF_UNIX)
    s.connect(path)
    buf = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            log("Hyprland olay soketi kapandı")
            os._exit(1)
        buf += chunk
        *lines, buf = buf.split(b"\n")
        for line in lines:
            if line.startswith(b"custom>>claude-voice "):
                voice.request(line.split(b" ", 1)[1].decode().strip())


def clean_profile():
    """Oturum geri yükleme olmasın: her açılış tek hap penceresiyle başlar.

    Chromium kapatılınca (servis durunca, oturum bitince) profil çoğu zaman
    "Crashed" işaretli kalıyor ve bir sonraki açılışta eski hap + sohbet
    pencerelerini geri getiriyordu — iki hap penceresi, Lua hangisini
    oynatacağını bilemez. Chromium kapalıyken yapılır.
    """
    default = os.path.join(PROFILE, "Default")
    shutil.rmtree(os.path.join(default, "Sessions"), ignore_errors=True)
    prefs = os.path.join(default, "Preferences")
    try:
        with open(prefs) as f:
            data = json.load(f)
    except (OSError, ValueError):
        return
    data.setdefault("profile", {}).update(exit_type="Normal", exited_cleanly=True)
    with open(prefs, "w") as f:
        json.dump(data, f)


def kill_strays():
    """Bu profili kullanan artık Chromium'ları kapat (profil yalnız bu servisin).

    Önceki servis örneğinin Chromium'u henüz kapanmadıysa yenisi kendini ona
    devredip çıkıyor, eski süreç ikinci bir hap penceresi açıyordu (servis
    yeniden başlarken görüldü, 4 Eki 2026).
    """
    # Chromium süreç başlığını yeniden yazıyor: /proc/*/cmdline argümanları \0 ile
    # değil boşlukla ayrılmış tek bir dizgi. Bayrak, ardından boşluk / \0 / son
    # gelecek şekilde aranır (…/chromium2 gibi bir yolla karışmasın).
    flag = f"--user-data-dir={PROFILE}".encode()
    pids = []
    for d in os.listdir("/proc"):
        if not d.isdigit() or int(d) == os.getpid():
            continue
        try:
            with open(f"/proc/{d}/cmdline", "rb") as f:
                cmd = f.read().rstrip(b"\0")
        except OSError:
            continue
        exe = os.path.basename(cmd.split(b"\0")[0].split(b" ")[0])
        if b"chromium" in exe and (cmd.endswith(flag) or flag + b" " in cmd or flag + b"\0" in cmd):
            pids.append(int(d))
    for pid in pids:
        try:
            os.kill(pid, 15)
        except OSError:
            pass
    if pids:
        log("artık Chromium kapatılıyor:", pids)
        gone = wait(lambda: not any(os.path.exists(f"/proc/{p}") for p in pids), 5)
        if not gone:
            for pid in pids:
                try:
                    os.kill(pid, 9)
                except OSError:
                    pass
            time.sleep(0.5)


def launch():
    kill_strays()
    clean_profile()
    return subprocess.Popen(
        [
            CHROMIUM,
            f"--user-data-dir={PROFILE}",
            f"--app={URL}",
            f"--remote-debugging-port={PORT}",
            "--remote-debugging-address=127.0.0.1",
            f"--load-extension={EXTENSION}",
            # Chromium 137+ --load-extension'ı varsayılan olarak yok sayıyor.
            "--disable-features=DisableLoadExtensionCommandLineSwitch",
            # Sohbet penceresini session.js kullanıcı hareketi olmadan açabilsin.
            # Yalnız bu profil; tek açılan sayfa claude.ai.
            "--disable-popup-blocking",
            "--no-first-run",
            "--no-default-browser-check",
            # Pencereler gizli alanda doğuyor: Chromium kendini "görünmez" sayıp
            # (document.hidden) hiç kare üretmiyordu — tuşa basınca pencere geliyor
            # ama içi boş kalıyordu; ResizeObserver da durduğu için hap büyümüyordu.
            # Odaklamak ya da Hyprland render_unfocused düzeltmedi; bu üçü düzeltti.
            # Boştaki işlemci yine %0 (sayfa durgun).
            "--disable-backgrounding-occluded-windows",
            "--disable-renderer-backgrounding",
            "--disable-background-timer-throttling",
            # Test kancası (servis birimi ayarlamaz): ör. gerçek mikrofon yerine
            # kayıt — "--use-fake-device-for-media-stream
            # --use-file-for-fake-audio-capture=soru.wav%noloop". Desktop.md "Test".
            *os.environ.get("CLAUDE_VOICE_EXTRA_FLAGS", "").split(),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def browser_id():
    """Çalışan Chromium'un kimliği (DevTools tarayıcı uç noktası; her açılışta yeni)."""
    try:
        return json.load(urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json/version", timeout=1))["webSocketDebuggerUrl"]
    except (OSError, ValueError, KeyError):
        return None


def attach(expect=None, timeout=60):
    """Asıl sayfaya bağlan, oturum betiğini kur (her bağlantıda yeniden).

    expect: yeniden bağlanırken beklenen tarayıcı kimliği. Port 9333'te artık
    başka bir Chromium varsa (ör. servisin yeni örneği) ona bağlanılmaz: iki
    servis aynı sayfada sesli modu aynı anda açıp kapatmaya çalışıyordu.
    """
    if expect and browser_id() != expect:
        raise RuntimeError("port başka bir Chromium'a geçmiş")
    page = Page(timeout=timeout, step=0.1)
    page.call("Page.enable")
    # Bağlantı açık kaldıkça geçerli (servis bağlantıyı hiç kapatmıyor).
    page.call("Emulation.setDefaultBackgroundColorOverride", color=BOX_RGB)
    # Runtime açık değilse binding yalnız o anki belgeye kurulur: sayfa bağlandıktan
    # sonra kendini yeniden yükleyince (claude.ai açılışta yapıyor) yeni belgede
    # claudeVoice yoktu, sayfanın hiçbir haberi servise ulaşmıyordu (4 Eki 2026).
    page.call("Runtime.enable")
    page.call("Runtime.addBinding", name="claudeVoice")
    page.call("Page.addScriptToEvaluateOnNewDocument", source=SESSION_JS)
    page.call("Runtime.evaluate", expression=SESSION_JS)
    page.ws.settimeout(None)
    return page


def daemon():
    # Tek örnek: ikinci bir servis (ör. elle başlatılan test kopyası) mevcut olanın
    # Chromium'unu "artık" sanıp öldürür, sonra ikisi aynı sayfayı yönetirdi.
    # ALONE çıkış kodu birimde RestartPreventExitStatus: yeniden denenmez.
    lock = open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "claude-voice.lock"), "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        log("başka bir örnek çalışıyor, çıkılıyor")
        sys.exit(ALONE)
    # systemd durdururken SIGTERM gelir: varsayılan davranış Python'u temizlik
    # yapmadan öldürür. Chromium kendini D-Bus ile kendi scope'una taşıdığından
    # (app-org.chromium.Chromium-*.scope) servisle birlikte ölmüyor; finally
    # bloğu onu kapatabilsin diye SIGTERM sıradan bir çıkışa çevrilir.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    chromium = launch()
    voice = Voice()
    try:
        page = attach()
        me = browser_id()
        threading.Thread(target=hypr_events, args=(voice,), daemon=True).start()
        # Servis tuşla başlatıldıysa hap çoktan görünür olabilir (Lua gösterdi,
        # ama olayı dinleyen yoktu): sesli modu şimdi aç.
        w = pill()
        if w and not w["workspace"]["name"].startswith("special:"):
            voice.request("show")
        log("hazır")

        while True:
            try:
                msg = json.loads(page.ws.recv())
            except (websocket.WebSocketException, OSError) as e:
                # Sayfa bağlantısı koptu ama Chromium yaşıyorsa yeniden bağlan
                # (sayfa yenilendi); yalnız Chromium ölünce çık (systemd yeniden
                # başlatır). Hap penceresi kapandıysa (Chromium pencere kalmayınca
                # da açık kalabiliyor) sekme yok: beklemeden çık — eskiden 60 sn
                # bekleniyordu, o arada Copilot tuşu hiçbir şey açmıyordu.
                if chromium.poll() is not None:
                    raise
                log("sayfa bağlantısı koptu, yeniden bağlanılıyor:", e)
                page = attach(expect=me, timeout=1.5)
                continue
            if msg.get("method") != "Runtime.bindingCalled":
                continue
            try:
                event = json.loads(msg["params"]["payload"])
            except ValueError:
                continue  # eski sürümün biçimi: yok say
            if not isinstance(event, dict):
                continue
            if event.get("chat") in ("show", "hide"):
                on = "true" if event["chat"] == "show" else "false"
                subprocess.run(["hyprctl", "eval", f"claude_voice_chat({on})"], capture_output=True)
            width = event.get("width")
            if isinstance(width, int) and WIDTH_MIN <= width <= WIDTH_MAX:
                subprocess.run(["hyprctl", "eval", f"claude_voice_width({width})"], capture_output=True)
    except (websocket.WebSocketException, OSError, RuntimeError) as e:
        log("çıkılıyor:", e)
    finally:
        chromium.terminate()
        try:
            chromium.wait(5)
        except subprocess.TimeoutExpired:
            chromium.kill()
        kill_strays()  # kendi scope'una kaçmış alt süreçler
    sys.exit(1)  # beklenmedik çıkış: systemd yeniden başlatır


def main():
    if sys.argv[1:] == ["--daemon"]:
        daemon()
    else:
        subprocess.run(["hyprctl", "eval", "claude_voice_toggle()"], check=False)


main()
