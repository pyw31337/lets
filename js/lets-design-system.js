/* LDS interaction primitives. No framework dependency. */
(function () {
  'use strict';
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  function carousel(root) {
    if (root.dataset.ldsCarouselReady) return;
    root.dataset.ldsCarouselReady = '1';
    let down = false, startX = 0, startScroll = 0, moved = false;
    root.addEventListener('pointerdown', e => { if (e.pointerType === 'mouse' && e.button !== 0) return; down = true; moved = false; startX = e.clientX; startScroll = root.scrollLeft; root.classList.add('is-dragging'); root.setPointerCapture?.(e.pointerId); });
    root.addEventListener('pointermove', e => { if (!down) return; const dx = e.clientX - startX; if (Math.abs(dx) > 4) moved = true; root.scrollLeft = startScroll - dx; });
    const up = e => { if (!down) return; down = false; root.classList.remove('is-dragging'); root.releasePointerCapture?.(e.pointerId); };
    root.addEventListener('pointerup', up); root.addEventListener('pointercancel', up);
    root.addEventListener('click', e => { if (moved) { e.preventDefault(); e.stopPropagation(); moved = false; } }, true);
  }
  function init() { document.querySelectorAll('[data-lds-carousel]').forEach(carousel); document.documentElement.classList.toggle('lds-reduced-motion', reduce); }
  window.LDS = Object.assign(window.LDS || {}, { init, carousel });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
