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
  async function registerPWA(path = '/sw.js') { if (!('serviceWorker' in navigator)) return null; try { return await navigator.serviceWorker.register(path, { scope: './' }); } catch (_) { return null; } }
  async function enableNotifications() {
    if (!('Notification' in window)) return { supported: false, permission: 'unsupported' };
    const permission = Notification.permission === 'default' ? await Notification.requestPermission() : Notification.permission;
    return { supported: true, permission };
  }
  function notify(title, options = {}) { if ('Notification' in window && Notification.permission === 'granted') return new Notification(title, options); return null; }
  function init() { document.querySelectorAll('[data-lds-carousel]').forEach(carousel); document.documentElement.classList.toggle('lds-reduced-motion', reduce); }
  window.LDS = Object.assign(window.LDS || {}, { init, carousel, registerPWA, enableNotifications, notify });
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
