// claude-voice paneli — hap genişliğini açıkça verir ki panel.css onu yumuşakça
// kaydırabilsin (CSS, max-content gibi bir anahtar sözcükten piksele geçiş
// yapamıyor). Hapın İÇERİĞİNİ (düğme grubu) gözler: ses simgesi 32px ↔ Cancel
// 94px ↔ Stop 79px; hap = içerik + 16px iç boşluk.
//
// Pencere (= koyu kutu) hapı 34px yan payla sarar: hedef pencere genişliği
// <html data-cv-width>'e yazılır. session.js (ana dünya, CDP binding'i olan)
// onu servise iletir, lua/voice.lua pencereyi hapla aynı anda büyütür. Pay elle
// ayarlanan 116×86 pencereden (hap 48 + 2×34, 4 Eki 2026).
//
// Hap yeniden çizilirse (React) gözlemci yeni öğeye taşınır.
(() => {
  const PAD = 16; // panel.css: hap padding 6px 8px
  const SIDE = 34; // kutunun hapın iki yanındaki payı
  let pill = null, group = null, ro = null, width = 0;

  const measure = () => {
    if (!pill || !group) return;
    const w = Math.round(group.getBoundingClientRect().width) + PAD;
    if (w <= PAD || w === width) return;
    width = w;
    pill.style.setProperty('width', w + 'px', 'important');
    document.documentElement.dataset.cvWidth = String(w + 2 * SIDE);
  };

  const check = () => {
    const p = document.querySelector('fieldset .bg-surface-3');
    const g = p && p.querySelector('.absolute.bottom-0.right-0');
    if (g && g !== group) {
      pill = p; group = g; width = 0;
      ro && ro.disconnect();
      ro = new ResizeObserver(measure);
      ro.observe(g);
      measure();
    }
  };

  // document'a bağlı, <html>'e değil: claude.ai yüklenirken kök öğeyi değiştirebiliyor.
  new MutationObserver(check).observe(document, { subtree: true, childList: true });
  check();

  // claude.ai'nin "hareketi azalt" ayarı (<html data-reduce-motion="true">, hesaptan
  // geliyor) sayfadaki BÜTÜN animasyon sürelerini 0.01ms'ye eziyor ve uzantının
  // stili o !important'ı yenemiyor: durum ışıması ve düğmenin belirmesi hiç
  // görünmüyordu. Panel kendi geçişleri için var; yalnız bu sayfada kapatılır,
  // başka claude.ai pencerelerine dokunulmaz.
  const motion = () => {
    const root = document.documentElement;
    if (root && root.getAttribute('data-reduce-motion') === 'true') root.setAttribute('data-reduce-motion', 'false');
  };
  new MutationObserver(motion).observe(document, { subtree: true, childList: true, attributes: true, attributeFilter: ['data-reduce-motion'] });
  motion();
})();
