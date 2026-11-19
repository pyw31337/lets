/**
 * Let's Design System (LDS v2.4.0)
 * Interaction Primitives: Tactile Carousel, Desktop Drag-to-Scroll & Touch Native Swipe
 * 
 * Philosophy:
 * - Touch devices use native momentum scrolling (zero JS interference with clicks).
 * - Desktop mouse users enjoy smooth drag-to-scroll with generous jitter tolerance (10px).
 * - Click events on nested buttons/links are NEVER suppressed during normal clicks.
 */
(function () {
  'use strict';

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /**
   * Universal Tactile Carousel & Scroll Controller
   */
  function enableTactileCarousel(root) {
    if (!root || root.dataset.ldsCarouselReady === '1') return;
    root.dataset.ldsCarouselReady = '1';

    let isMouseDown = false;
    let startX = 0;
    let startScrollLeft = 0;
    let hasDragged = false;
    let lastX = 0;
    let lastTime = 0;
    let velocity = 0;
    let momentumFrame = null;

    // Native touch optimization
    root.style.overflowX = 'auto';
    root.style.webkitOverflowScrolling = 'touch';
    root.style.scrollbarWidth = 'none';
    root.classList.add('lds-tactile-carousel');

    // Desktop Mouse Drag Handling Only (Touch uses 100% native smooth swipe)
    root.addEventListener('mousedown', (e) => {
      // Left click only
      if (e.button !== 0) return;

      if (momentumFrame) {
        cancelAnimationFrame(momentumFrame);
        momentumFrame = null;
      }

      isMouseDown = true;
      hasDragged = false;
      startX = e.clientX;
      lastX = e.clientX;
      startScrollLeft = root.scrollLeft;
      lastTime = performance.now();
      velocity = 0;

      const onMouseMove = (moveEvent) => {
        if (!isMouseDown) return;
        const currentX = moveEvent.clientX;
        const dx = currentX - startX;

        // Jitter tolerance threshold: must move more than 10px to count as drag
        if (Math.abs(dx) > 10) {
          hasDragged = true;
          root.classList.add('is-dragging');
        }

        if (hasDragged) {
          root.scrollLeft = startScrollLeft - dx;
          const now = performance.now();
          const dt = Math.max(1, now - lastTime);
          velocity = (currentX - lastX) / dt;
          lastX = currentX;
          lastTime = now;
        }
      };

      const onMouseUp = () => {
        isMouseDown = false;
        window.removeEventListener('mousemove', onMouseMove);
        window.removeEventListener('mouseup', onMouseUp);

        setTimeout(() => {
          root.classList.remove('is-dragging');
        }, 50);

        // Apply light momentum glide on desktop mouse flick
        if (!reduceMotion && hasDragged && Math.abs(velocity) > 0.3) {
          let currentVelocity = velocity * 12;
          const friction = 0.92;

          const stepMomentum = () => {
            if (Math.abs(currentVelocity) < 0.5 || isMouseDown) {
              momentumFrame = null;
              return;
            }
            root.scrollLeft -= currentVelocity;
            currentVelocity *= friction;
            momentumFrame = requestAnimationFrame(stepMomentum);
          };
          momentumFrame = requestAnimationFrame(stepMomentum);
        }
      };

      window.addEventListener('mousemove', onMouseMove);
      window.addEventListener('mouseup', onMouseUp);
    });

    // Suppress click ONLY if actual drag (> 10px) occurred
    root.addEventListener('click', (e) => {
      if (hasDragged) {
        e.preventDefault();
        e.stopPropagation();
        hasDragged = false;
      }
    }, true);
  }

  function init() {
    // Select all carousels, nav tracks, and segment tracks
    const selectors = [
      '[data-lds-carousel]',
      '.service-nav-bar',
      '.cat-carousel',
      '.segment-tabs',
      '#serviceNavBar',
      '#catBar'
    ];
    document.querySelectorAll(selectors.join(', ')).forEach(enableTactileCarousel);
    document.documentElement.classList.toggle('lds-reduced-motion', reduceMotion);
  }

  window.LDS = Object.assign(window.LDS || {}, {
    version: '2.4.0',
    init,
    carousel: enableTactileCarousel
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
