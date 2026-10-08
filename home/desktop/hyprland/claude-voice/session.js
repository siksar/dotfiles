// claude-voice — sesli oturumun sayfa tarafı. claude.ai'nin ANA dünyasında koşar:
// `claude-voice --watch` (voice.py) CDP ile her belgeye enjekte eder, çünkü
// burada iki şey lazım: pencere açmak (window.open) ve izleyiciye haber vermek
// (CDP binding `claudeVoice`). Uzantının içerik betiği (panel.js) ikisini de
// yapamıyor.
//
// Dört iş:
//  1. Durum: sesli modun hâli (bağlanıyor / dinliyor / duyuyor / düşünüyor / konuşuyor)
//     <html data-cv-state> özniteliğine yazılır; panel.css kutunun çevresindeki
//     ışımayı buna göre çizer. Kaynak, mesaj kutusunun yer tutucu metni —
//     claude.ai sesli mod durumunu orada gösteriyor.
//  2. Sohbet penceresi: hapın üstünde açılan ikinci pencere. about:blank bir
//     popup; içeriği bu sayfadaki mesajların kopyası (claude.ai'nin kendi stil
//     sayfalarıyla), yani ikinci bir claude.ai oturumu açılmaz. Boyutu sabit
//     (rules.lua) — Chromium penceresi görünürken boyutlandırılınca ~150 ms
//     bozuk kare çiziyor.
//  3. Karar: Claude'un son cevabı okumaya değerse (kod, tablo, liste, bağlantı,
//     görsel, uzun metin) sohbet penceresi kendiliğinden açılır. Hapın koyu
//     kutusuna tıklamak elle aç/kapa yapar; elle kapatılan cevap bir daha
//     kendiliğinden açtırmaz, yalnız sonraki okumaya değer cevap açar.
//  4. Genişlik: hap büyüyüp küçülünce pencerenin hedef genişliği servise gider.
(() => {
  // İşaret belgede, pencerede değil: belge yenilenip pencere aynı kalırsa yeniden kurulsun.
  if (document.__claudeVoiceSession) return;
  document.__claudeVoiceSession = true;

  const CHAT_CSS = @CHAT_CSS@;
  const CHAT_NAME = 'claude-voice-chat';
  const MAX_ROWS = 40;
  const RISE_MS = 420; // chat.css .cv-new süresiyle aynı

  const send = (m) => { try { window.claudeVoice(JSON.stringify(m)); } catch (e) { /* izleyici yok */ } };

  // ---- 1. durum -----------------------------------------------------------

  const STATES = {
    'Connecting...': 'connecting',
    'Listening...': 'listening',
    'Processing...': 'processing',
    'Claude is speaking...': 'speaking',
    'Reconnecting...': 'reconnecting',
  };
  const LABELS = {
    idle: 'Sesli mod kapalı',
    connecting: 'Bağlanıyor…',
    listening: 'Dinliyor…',
    processing: 'Düşünüyor…',
    speaking: 'Konuşuyor…',
    reconnecting: 'Yeniden bağlanıyor…',
    hearing: 'Duyuyor…',
  };

  const readState = () => {
    // Stop düğmesi yalnız sesli mod açıkken var (voice.py STOP_BUTTON ile aynı).
    if (!document.querySelector('fieldset .gap-1.shrink-0 > button.h-8')) return 'idle';
    const p = document.querySelector('[data-testid=chat-input] p[data-placeholder]');
    // Yer tutucu yoksa kutuda canlı döküm var: kullanıcı konuşuyor.
    return (p && STATES[p.getAttribute('data-placeholder')]) || 'hearing';
  };

  // ---- 2. sohbet penceresi ------------------------------------------------

  let chat = null;
  // Kullanıcı tekerlekle kaydırırsa otomatik takip FOLLOW_PAUSE ms durur.
  const FOLLOW_PAUSE = 6000;
  let pausedUntil = 0;

  const chatWindow = (create) => {
    if (chat && !chat.closed) return chat;
    // Aynı adla açmak var olan popup'ı döndürür — sayfa yeniden yüklense de.
    // Yoksa yeni about:blank popup açılır (--disable-popup-blocking: kullanıcı
    // hareketi olmadan da açılabilsin). Hyprland onu "claude-voice-chat"
    // kuralıyla gizli alana koyar, izleyici gösterir.
    if (!create) return null;
    const w = window.open('', CHAT_NAME, 'popup,width=480,height=360');
    if (!w) return null;
    chat = w;
    setupChat(w);
    return w;
  };

  const setupChat = (w) => {
    const d = w.document;
    if (d.getElementById('cv-list')) { syncStyles(d); return; }
    d.title = CHAT_NAME;
    d.head.innerHTML = '';
    syncStyles(d);
    const own = d.createElement('style');
    own.id = 'cv-own';
    own.textContent = CHAT_CSS;
    d.head.append(own);
    d.body.innerHTML =
      '<header id="cv-head"><span id="cv-dot"></span><span id="cv-status"></span>' +
      '<button id="cv-close" title="Küçült">' +
      '<svg viewBox="0 0 20 20" width="16" height="16"><path d="M5 8l5 5 5-5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>' +
      '</button></header>' +
      '<main id="cv-list" class="cds-root text-primary"><div id="cv-empty">Henüz bir şey konuşulmadı.</div></main>';
    d.getElementById('cv-close').addEventListener('click', () => setExpanded(false, true));
    d.getElementById('cv-list').addEventListener('wheel', () => { pausedUntil = performance.now() + FOLLOW_PAUSE; }, { passive: true });
  };

  // claude.ai'nin stil sayfaları ve tema öznitelikleri popup'a da gelsin:
  // kopyalanan mesajlar sitedeki gibi görünür (yazı tipi, kod, tablo, koyu tema).
  const syncStyles = (d) => {
    const src = [...document.querySelectorAll('link[rel=stylesheet], style')];
    const have = d.head.querySelectorAll('[data-cv-copy]').length;
    if (have !== src.length) {
      d.head.querySelectorAll('[data-cv-copy]').forEach((e) => e.remove());
      const own = d.getElementById('cv-own');
      for (const s of src) {
        const c = d.importNode(s, true);
        c.setAttribute('data-cv-copy', '');
        d.head.insertBefore(c, own);
      }
    }
    for (const a of document.documentElement.attributes) {
      if (a.name !== 'data-cv-state' && a.name !== 'style') d.documentElement.setAttribute(a.name, a.value);
    }
    d.documentElement.style.cssText = document.documentElement.style.cssText;
  };

  // ---- aynalama -------------------------------------------------------------

  const rows = () => [...document.querySelectorAll('[data-testid=transcript-list] [data-testid=transcript-row]')]
    .filter((r) => r.querySelector('[data-testid=user-message], [data-testid=assistant-message]'));

  // Okumaya değer mi: sesle dinlemesi zor ya da görmesi faydalı içerik. Sesli
  // modda Claude kodu/tabloyu genelde reddediyor ("sesli görüşmedeyiz, metin
  // sohbetine geçelim mi?" — 4 Eki 2026 denemesi); asıl tetik uzun cevap ve
  // kaynak bağlantıları (web araması). Ölçü cevabın GÖVDESİ: ekran okuyucu ön eki
  // ("Claude responded:") ve "just now" gibi parçalar dışarıda. innerText değil
  // textContent — hap stili sayfayı visibility:hidden yapıyor, innerText boş döner.
  const worthReading = (a) => {
    const body = a && a.querySelector('.font-claude-response');
    if (!body) return false;
    if (body.querySelector('pre, table, img, [data-testid*=artifact], a[href^="http"]')) return true;
    if (body.querySelectorAll('li').length >= 3) return true;
    return (body.textContent || '').trim().length > 280; // ≈ 15+ sn konuşma
  };

  let lastState = null;
  let expanded = false;
  let dismissedKey = null; // elle kapatılan cevabın anahtarı
  let lastKey = null;

  const mirror = () => {
    const state = readState();
    if (state !== lastState) {
      lastState = state;
      document.documentElement.setAttribute('data-cv-state', state);
    }

    const rs = rows();
    const last = rs.length ? rs[rs.length - 1] : null;
    const answer = last && last.querySelector('[data-testid=assistant-message]');
    const key = rs.length + ':' + (answer ? 'a' : 'u');

    if (answer && worthReading(answer) && key !== dismissedKey && !expanded) setExpanded(true);
    lastKey = key;

    const w = chatWindow(expanded);
    if (!w) return;
    const d = w.document;
    syncStyles(d);
    d.documentElement.setAttribute('data-cv-state', state);
    d.getElementById('cv-status').textContent = LABELS[state] || '';

    const list = d.getElementById('cv-list');
    render(d, list, rs.slice(-MAX_ROWS));
    if (performance.now() > pausedUntil) follow(list);
  };

  // Otomatik kaydırma. Claude konuşurken söylenen kelime text-muted → text-primary
  // olur; liste o an söylenen kelimeyi üst üçte birde tutar (karaoke). Konuşma
  // yoksa en alta iner.
  const follow = (list) => {
    const last = list.lastElementChild;
    const body = last && last.querySelector('.font-claude-response');
    const spoken = body ? body.querySelectorAll('span.text-primary') : [];
    if (spoken.length && body.querySelector('span.text-muted')) {
      const w = spoken[spoken.length - 1];
      const top = w.getBoundingClientRect().top - list.getBoundingClientRect().top + list.scrollTop;
      list.scrollTop = Math.max(0, top - list.clientHeight * 0.33);
    } else {
      list.scrollTop = bottomOf(list) - list.clientHeight;
    }
  };

  // "En alt" = son satırın gerçek alt kenarı, scrollHeight değil: kopyada mutlak
  // konumlu süslemeler (yazarken dönen yıldız, 256px) listeyi aşağı uzatıyor,
  // en alta kaydırınca metin görünür alanın üstünde kalıyordu.
  const bottomOf = (list) => {
    const last = list.lastElementChild;
    return last ? last.offsetTop + last.offsetHeight + 18 : list.scrollHeight; // 18 = alt boşluk (chat.css)
  };

  // Satır satır karşılaştır: yalnız değişen satır yeniden kopyalanır, yalnız
  // gerçekten yeni gelen satır "süzülme" animasyonu alır. Hepsini her seferinde
  // baştan kurmak, Claude yazarken animasyonu saniyede birkaç kez yeniden
  // oynatıp titretiyordu.
  const signature = (r) => r.innerHTML.length + ':' + (r.textContent || '').length;
  const render = (d, list, src) => {
    const empty = d.getElementById('cv-empty');
    if (!src.length) {
      list.replaceChildren(empty || Object.assign(d.createElement('div'), { id: 'cv-empty', textContent: 'Henüz bir şey konuşulmadı.' }));
      return;
    }
    if (empty) empty.remove();
    // Sohbet değiştiyse ya da MAX_ROWS sınırında baş kaydıysa baştan kur
    // (ilk satırın metni değişir).
    const first = (src[0].textContent || '').slice(0, 120);
    const reset = list.children.length > src.length || list.dataset.cvFirst !== first;
    if (reset) list.replaceChildren();
    list.dataset.cvFirst = first;
    src.forEach((r, i) => {
      const sig = signature(r);
      const old = list.children[i];
      if (old && old.dataset.cvSig === sig) return;
      const c = d.importNode(r, true);
      // Etkileşimli parçalar (kopyala, beğen, yeniden dene…) burada anlamsız.
      c.querySelectorAll('[data-testid=message-actions], button, [role=button]').forEach((e) => e.remove());
      // claude.ai cevap yazılırken satır içi dev yükseklikler veriyor (sayfa
      // kaydırması için yer ayırma, 3420px gördük): metin boşluğun tepesinde
      // kalıp liste en altta hiçbir şey göstermiyordu.
      for (const e of [c, ...c.querySelectorAll('[style]')]) {
        e.style.removeProperty('min-height');
        e.style.removeProperty('height');
      }
      c.dataset.cvSig = sig;
      if (old) {
        // Süzülme animasyonu sürerken satır yenilenirse animasyon kaldığı yerden
        // devam etsin (negatif gecikme); yoksa yarıda kesilip sıçrardı.
        const age = old.dataset.cvBorn ? performance.now() - Number(old.dataset.cvBorn) : Infinity;
        if (age < RISE_MS) {
          c.dataset.cvBorn = old.dataset.cvBorn;
          c.classList.add('cv-new');
          c.style.animationDelay = `-${Math.round(age)}ms`;
        }
        old.replaceWith(c);
      } else {
        if (!reset) {
          c.dataset.cvBorn = String(performance.now());
          c.classList.add('cv-new');
        }
        list.append(c);
      }
    });
  };

  const setExpanded = (on, byUser) => {
    if (on === expanded) return;
    expanded = on;
    if (!on && byUser) dismissedKey = lastKey;
    if (on) {
      if (!chatWindow(true)) { expanded = false; return; }
      mirror();
      const list = chat.document.getElementById('cv-list');
      list.scrollTop = bottomOf(list) - list.clientHeight;
    }
    document.documentElement.toggleAttribute('data-cv-expanded', on);
    send({ chat: on ? 'show' : 'hide' });
  };

  // İzleyici panel her açılışta çağırır: yeni oturum kompakt başlar.
  window.__claudeVoiceReset = () => {
    dismissedKey = null;
    if (expanded) { expanded = false; document.documentElement.removeAttribute('data-cv-expanded'); }
    schedule();
  };
  // İzleyici, panel kapanırken sohbet penceresini kendisi gizler; durum eşlensin.
  // Son cevap da "kapatıldı" sayılır: yoksa kapanış sırasında aynalama o cevabı
  // yine okumaya değer bulup sohbeti geri açtırıyordu (kapanan panelle yarış).
  window.__claudeVoiceCollapsed = () => {
    expanded = false;
    dismissedKey = lastKey;
    document.documentElement.removeAttribute('data-cv-expanded');
  };

  // Hapın koyu kutusuna tıklamak (düğmenin kendisi değil) sohbeti aç/kapa yapar.
  document.addEventListener('click', (e) => {
    const box = e.target.closest && e.target.closest('fieldset div:has(> .bg-surface-3)');
    if (!box || e.target.closest('button')) return;
    setExpanded(!expanded, true);
  }, true);

  // Değişiklikleri 120 ms'de bir topla; claude.ai akış hâlinde saniyede onlarca
  // küçük değişiklik yapıyor. "class" da dinlenir: Claude konuşurken söylenen
  // kelime yalnız sınıf değiştiriyor (text-muted → text-primary); dinlenmeyince
  // karaoke sohbet penceresinde ilk kelimelerde donup kalıyordu.
  let pending = false;
  const schedule = () => {
    if (pending) return;
    pending = true;
    setTimeout(() => { pending = false; mirror(); }, 120);
  };
  // <html> değil document: claude.ai yüklenirken kök öğeyi değiştirebiliyor ve eski
  // kökteki gözlemci susuyordu (durum "connecting"te donuyordu, 4 Eki 2026).
  new MutationObserver(schedule).observe(document, {
    subtree: true, childList: true, characterData: true, attributes: true,
    attributeFilter: ['data-placeholder', 'data-is-streaming', 'class'],
  });
  schedule();

  // ---- 4. pencere genişliği -------------------------------------------------
  // panel.js hapın hedef genişliğini <html data-cv-width>'e yazar (uzantının
  // betiği binding'e erişemiyor); buradan servise, oradan lua/voice.lua'ya.
  // Cancel → Stop gibi geçişlerde düğme 700 ms boyunca her karede genişliyor:
  // en çok 50 ms'de bir gönderilir, son değer her zaman gider.
  let sentWidth = 0, widthTimer = null;
  const sendWidth = () => {
    widthTimer = null;
    const w = Number(document.documentElement.dataset.cvWidth) || 0;
    if (w && w !== sentWidth) { sentWidth = w; send({ width: w }); }
  };
  new MutationObserver(() => { widthTimer = widthTimer || setTimeout(sendWidth, 50); })
    .observe(document, { subtree: true, attributes: true, attributeFilter: ['data-cv-width'] });
  sendWidth();
})();
