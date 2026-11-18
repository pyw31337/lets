(() => {
  const root = document.querySelector('[data-graphs-full]');
  if (!root) return;
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  fetch('../data/master_ecosystem_pulse.json?t=' + Date.now()).then(r => r.json()).then(data => {
    const devices = data.automation_devices || [];
    root.innerHTML = devices.map(device => {
      const metric = device.metrics?.day || {labels: [], values: [], unit: '건'};
      const values = metric.values || [];
      const labels = metric.labels || [];
      const max = Math.max(...values, 1);
      const min = Math.min(...values, 0);
      const span = Math.max(max - min, 1);
      const points = values.map((value, index) => {
        const x = 24 + index * (288 / Math.max(values.length - 1, 1));
        const y = 124 - ((value - min) / span) * 94;
        return {x, y, value, label: labels[index] || String(index + 1)};
      });
      const line = points.map((point, index) => `${index ? 'L' : 'M'}${point.x} ${point.y}`).join(' ');
      const area = `${line} L ${points.at(-1)?.x || 312} 124 L 24 124 Z`;
      const color = device.badge_color || '#315bea';
      return `<article class="chart-card"><h3>${esc(device.name)}</h3><p>${esc(device.service_name || '')} · ${esc(metric.unit || '건')}</p><svg viewBox="0 0 330 145" role="img" aria-label="${esc(device.name)} 기간별 처리량"><line x1="24" y1="124" x2="312" y2="124" stroke="#dfe5ef"/><path d="${area}" fill="${color}18"/><path d="${line}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>${points.map(point => `<circle cx="${point.x}" cy="${point.y}" r="3.5" fill="#fff" stroke="${color}" stroke-width="2" tabindex="0"><title>${esc(point.label)}: ${Number(point.value).toLocaleString()} ${esc(metric.unit || '건')}</title></circle>`).join('')}</svg><div class="chart-meta"><span>${esc(labels[0] || '')}</span><b>${values.length ? Number(values.at(-1)).toLocaleString() : '실측 대기'}</b><span>${esc(labels.at(-1) || '')}</span></div></article>`;
    }).join('');
  }).catch(() => { root.innerHTML = '<div class="empty">시계열 원장을 불러오지 못했습니다.</div>'; });
})();
