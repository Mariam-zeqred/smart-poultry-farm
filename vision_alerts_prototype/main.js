/**
 * UI wiring: theme, polling loop, rendering, simulate buttons, toasts.
 * Talks only to the functions exposed by firebase-client.js / alerts-store.js
 * / vision-alert-engine.js — kept separate so this file could be deleted
 * wholesale once the same logic lives in the Flutter app (stage 4) without
 * touching the engine/store modules.
 */

const SCENARIO_META = [
  { key: 'normal', label: 'Normal baseline', color: 'var(--success)' },
  { key: 'unhealthy_warning', label: 'Unhealthy rate: warning (~17%)', color: 'var(--warning)' },
  { key: 'unhealthy_critical', label: 'Unhealthy rate: critical (40%)', color: 'var(--error)' },
  { key: 'activity_low', label: 'Sustained low activity', color: 'var(--warning)' },
  { key: 'bird_count_drop', label: 'Bird count drop', color: 'var(--error)' },
  { key: 'overcrowding', label: 'Overcrowding hotspot spike', color: 'var(--warning)' },
  { key: 'feeding_stalled', label: 'Feeding stalled', color: 'var(--error)' },
  { key: 'combined_mortality', label: 'Combined: drop + unhealthy', color: 'var(--error)' },
  { key: 'stale', label: 'AI feed goes stale', color: 'var(--warning)' },
];

const TYPE_DISPLAY_NAMES = {
  temperature_high: 'High Temperature',
  temperature_low: 'Low Temperature',
  humidity_high: 'High Humidity',
  humidity_low: 'Low Humidity',
  gas_detected: 'Gas Detection',
  gas_critical: 'Critical Gas Level',
  temp_critical_low: 'Critical Low Temperature',
  temp_critical_high: 'Critical High Temperature',
  hum_critical_low: 'Critical Low Humidity',
  hum_critical_high: 'Critical High Humidity',
  vision_stale: 'AI Feed Offline',
  vision_unhealthy_rate: 'Unhealthy Rate',
  vision_activity_low: 'Low Activity',
  vision_bird_count_drop: 'Bird Count Drop',
  vision_overcrowding: 'Overcrowding',
  vision_feeding_stalled: 'Feeding Stalled',
  vision_combined_health_activity_risk: 'Health + Activity Risk',
  vision_combined_mortality_risk: 'Possible Mortality Event',
};

const THRESHOLD_LABELS = {
  unhealthyWarnPct: 'Unhealthy % (warning)',
  unhealthyCriticalPct: 'Unhealthy % (critical)',
  activityLowSustainedCount: 'Low-activity sessions to alarm',
  birdCountDropPct: 'Bird count drop %',
  birdCountSustainedCount: 'Drop sessions to alarm',
  hotspotSpikeRatio: 'Overcrowding spike ratio (x baseline)',
  feedingStalledPct: 'Feeding-stalled % floor',
  feedingSustainedCount: 'Feeding-stalled sessions to alarm',
  staleMinutes: 'Stale after (minutes)',
};

let currentThresholds = { ...DEFAULT_VISION_THRESHOLDS };
let lastProcessedTimestamp = null;
let seenAlertIds = new Set();
let firstAlertRender = true;

function typeDisplayName(type) {
  return TYPE_DISPLAY_NAMES[type] || (type || '').replace(/_/g, ' ').toUpperCase();
}
function severityIcon(sev) {
  return sev === 'critical' ? '🚨' : sev === 'warning' ? '⚠️' : 'ℹ️';
}
function escapeHTML(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}
function getCssVar(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || '#47A2C6';
}
function setPollStatus(text) {
  document.getElementById('pollStatus').textContent = text;
}

function sparklineSVG(values, color) {
  if (!values.length) return '<svg viewBox="0 0 100 40"></svg>';
  const w = 100, h = 40, pad = 4;
  const min = Math.min(...values), max = Math.max(...values);
  const range = max - min || 1;
  const stepX = values.length > 1 ? (w - pad * 2) / (values.length - 1) : 0;
  const points = values.map((v, i) => {
    const x = pad + i * stepX;
    const y = h - pad - ((v - min) / range) * (h - pad * 2);
    return `${x.toFixed(1)},${y.toFixed(1)}`;
  }).join(' ');
  return `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none">
    <polyline points="${points}" fill="none" stroke="${color}" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
  </svg>`;
}

// ---------- rendering ----------

function renderSnapshot(analysis) {
  const chip = document.getElementById('statusChip');

  if (!analysis || !analysis.timestamp) {
    chip.textContent = 'NO DATA';
    chip.className = 'chip stale';
    document.getElementById('statBirds').textContent = '—';
    document.getElementById('statActivity').textContent = '—';
    document.getElementById('statHealth').textContent = '—';
    document.getElementById('hotspotInfo').textContent = 'Hotspot: —';
    document.getElementById('lastUpdated').textContent = 'No analysis received yet — try Simulate: Normal baseline.';
    return;
  }

  const b = analysis.behavior || {};
  const h = analysis.health || {};
  // Simulated snapshots can land a little ahead of real Date.now() after a
  // long run of test clicks (see nextBaseTimestamp in alerts-store.js) —
  // clamp so the UI reads "just now" instead of a nonsensical "-3 min ago".
  const ageMin = Math.max(0, (Date.now() - analysis.timestamp) / 60000);
  const stale = ageMin > (currentThresholds.staleMinutes ?? 20);

  if (stale) {
    chip.textContent = 'STALE';
    chip.className = 'chip stale';
  } else {
    const status = (h.status || 'normal').toLowerCase();
    const cls = status === 'alert' ? 'alert' : status === 'watch' ? 'watch' : 'normal';
    chip.textContent = status.toUpperCase();
    chip.className = 'chip ' + cls;
  }

  document.getElementById('statBirds').textContent = b.birdCount ?? '—';
  document.getElementById('statActivity').textContent = b.activityLevel || '—';
  document.getElementById('statHealth').textContent = `${h.healthy ?? 0} / ${h.unhealthy ?? 0}`;

  const bd = b.behaviorBreakdown || {};
  const ed = Math.round((bd.eatDrink || 0) * 100);
  const mv = Math.round((bd.moving || 0) * 100);
  const rs = Math.max(0, 100 - ed - mv);
  document.getElementById('barEatDrink').style.width = ed + '%';
  document.getElementById('barMoving').style.width = mv + '%';
  document.getElementById('barRest').style.width = rs + '%';
  document.getElementById('lblEatDrink').textContent = ed + '%';
  document.getElementById('lblMoving').textContent = mv + '%';
  document.getElementById('lblRest').textContent = rs + '%';

  const hs = b.hotspot || {};
  document.getElementById('hotspotInfo').textContent =
    hs.row != null ? `Hotspot: row ${hs.row}, col ${hs.col} (intensity ${hs.intensity})` : 'Hotspot: —';

  const ageLabel = ageMin < 1 ? 'just now' : `${Math.round(ageMin)} min ago`;
  document.getElementById('lastUpdated').textContent = stale
    ? `Last updated ${ageLabel} — stale`
    : `Last updated ${ageLabel}`;
}

function renderSparklines(history) {
  document.getElementById('sparkBirds').innerHTML =
    sparklineSVG(history.map(r => r.birdCount), getCssVar('--primary'));
  document.getElementById('sparkUnhealthy').innerHTML =
    sparklineSVG(history.map(r => r.unhealthyPct), getCssVar('--error'));
}

function alertItemHTML(a) {
  const time = a.createdAt ? new Date(a.createdAt).toLocaleString() : '—';
  const resolvedCls = a.resolvedAt ? ' resolved' : '';
  return `
    <div class="alert-item severity-${a.severity}${resolvedCls}">
      <div class="row1">
        <span class="type-name">${severityIcon(a.severity)} ${typeDisplayName(a.type)}</span>
        <span class="time">${time}</span>
      </div>
      <div class="message">${escapeHTML(a.message || '')}</div>
      <div class="actions">
        ${a.resolvedAt
          ? '<span class="btn" disabled>Resolved</span>'
          : `<button class="btn" id="ack-${a.id}" ${a.acknowledgedAt ? 'disabled' : ''}>${a.acknowledgedAt ? 'Acknowledged' : 'Acknowledge'}</button>
             <button class="btn primary" id="res-${a.id}">Resolve</button>`}
      </div>
    </div>`;
}

function renderAlerts(alerts) {
  const showResolved = document.getElementById('showResolved').checked;
  const sevRank = { critical: 0, warning: 1, info: 2 };
  const sorted = [...alerts]
    .filter(a => showResolved || !a.resolvedAt)
    .sort((a, b) => {
      const ar = a.resolvedAt ? 1 : 0, br = b.resolvedAt ? 1 : 0;
      if (ar !== br) return ar - br;
      const sr = (sevRank[a.severity] ?? 3) - (sevRank[b.severity] ?? 3);
      if (sr !== 0) return sr;
      return (b.createdAt || 0) - (a.createdAt || 0);
    });

  const listEl = document.getElementById('alertList');
  listEl.innerHTML = sorted.length
    ? sorted.map(alertItemHTML).join('')
    : '<div class="empty-state">No alerts yet — try a Simulate scenario.</div>';

  sorted.forEach(a => {
    const ackBtn = document.getElementById('ack-' + a.id);
    const resBtn = document.getElementById('res-' + a.id);
    if (ackBtn) ackBtn.onclick = () => acknowledgeAlert(a.id).then(tick);
    if (resBtn) resBtn.onclick = () => resolveAlert(a.id).then(tick);
  });

  const active = alerts.filter(a => !a.resolvedAt);
  const badge = document.getElementById('alertBadge');
  if (active.length) {
    badge.style.display = 'flex';
    badge.textContent = active.length > 99 ? '99+' : String(active.length);
    badge.className = 'badge' + (active.some(a => a.severity === 'critical') ? '' : ' warning-only');
  } else {
    badge.style.display = 'none';
  }

  active.forEach(a => {
    if (!firstAlertRender && !seenAlertIds.has(a.id) && a.severity !== 'info') {
      showToast(a);
    }
    seenAlertIds.add(a.id);
  });
  firstAlertRender = false;
}

function showToast(alert) {
  const stack = document.getElementById('toastStack');
  const el = document.createElement('div');
  el.className = 'toast severity-' + alert.severity;
  el.innerHTML = `<strong>${severityIcon(alert.severity)} ${typeDisplayName(alert.type)}</strong><br>${escapeHTML(alert.message || '')}`;
  stack.appendChild(el);
  setTimeout(() => el.remove(), 8000);

  if (window.Notification && Notification.permission === 'granted') {
    new Notification(typeDisplayName(alert.type), { body: alert.message || '' });
  }
}

// ---------- simulate panel ----------

function buildSimGrid() {
  const grid = document.getElementById('simGrid');
  grid.innerHTML = SCENARIO_META.map(s =>
    `<button class="sim-btn" data-scenario="${s.key}"><span class="sev-dot" style="background:${s.color}"></span>${s.label}</button>`
  ).join('');
  grid.querySelectorAll('.sim-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const allBtns = grid.querySelectorAll('.sim-btn');
      allBtns.forEach(b => (b.disabled = true));
      const originalText = btn.textContent;
      btn.textContent = 'Running…';
      try {
        await simulateScenario(btn.dataset.scenario);
        await tick();
      } catch (e) {
        console.error(e);
        alert('Simulation failed: ' + e.message);
      } finally {
        allBtns.forEach(b => (b.disabled = false));
        btn.textContent = originalText;
      }
    });
  });
}

// ---------- thresholds panel ----------

async function loadThresholdsForm() {
  currentThresholds = await fetchVisionThresholds();
  const form = document.getElementById('thresholdsForm');
  form.innerHTML = Object.keys(DEFAULT_VISION_THRESHOLDS).map(key => `
    <div class="threshold-row">
      <label for="th-${key}">${THRESHOLD_LABELS[key] || key}</label>
      <input type="number" step="0.1" id="th-${key}" value="${currentThresholds[key]}" />
    </div>`).join('');
}

// ---------- poll loop ----------

// The background 8s interval and explicit calls (after a simulate click, an
// ack/resolve, a reset) can overlap. processLatestSnapshot/resetVisionTestData
// are already serialized (see alerts-store.js), but the read+render half of
// tick() isn't — two overlapping ticks' fetches can resolve out of order, and
// without a guard the OLDER one's stale data can paint over the newer one's
// render. `tickToken` makes each tick() check it's still the latest before
// touching the DOM; a superseded tick just discards its result.
let tickToken = 0;

async function tick() {
  const myToken = ++tickToken;
  setPollStatus('Checking…');
  try {
    const analysis = await dbGet('PoultrySystem/vision/analysis');
    if (analysis && analysis.timestamp && analysis.timestamp !== lastProcessedTimestamp) {
      await processLatestSnapshot(currentThresholds);
      lastProcessedTimestamp = analysis.timestamp;
    }
    const [alerts, history] = await Promise.all([fetchAllAlerts(), fetchVisionHistory()]);
    if (myToken !== tickToken) return; // a newer tick started while we were fetching — don't clobber it
    renderSnapshot(analysis);
    renderSparklines(history);
    renderAlerts(alerts);
    setPollStatus('Live · updated ' + new Date().toLocaleTimeString());
  } catch (e) {
    console.error(e);
    if (myToken === tickToken) setPollStatus('Error: ' + e.message);
  }
}

// ---------- bootstrap ----------

(function initTheme() {
  const saved = localStorage.getItem('gallinex_theme');
  if (saved) document.documentElement.setAttribute('data-theme', saved);
})();

document.getElementById('themeToggle').addEventListener('click', () => {
  const isDark = document.documentElement.getAttribute('data-theme') === 'dark'
    || (!document.documentElement.hasAttribute('data-theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
  const next = isDark ? 'light' : 'dark';
  document.documentElement.setAttribute('data-theme', next);
  localStorage.setItem('gallinex_theme', next);
});

document.getElementById('notifPermBtn').addEventListener('click', () => {
  if (!window.Notification) {
    alert('This browser does not support desktop notifications.');
    return;
  }
  Notification.requestPermission().then(p => {
    document.getElementById('notifPermBtn').textContent = p === 'granted' ? '🔔✅' : '🔕';
  });
});

document.getElementById('bellBtn').addEventListener('click', () => {
  document.getElementById('alertList').scrollIntoView({ behavior: 'smooth', block: 'center' });
});

document.getElementById('showResolved').addEventListener('change', tick);

document.getElementById('resetTestData').addEventListener('click', async () => {
  if (!confirm('Clear synthetic vision history + vision alerts? This does not touch real sensor data.')) return;
  const btn = document.getElementById('resetTestData');
  btn.disabled = true;
  try {
    await resetVisionTestData();
    lastProcessedTimestamp = null;
    await tick();
  } finally {
    btn.disabled = false;
  }
});

document.getElementById('saveThresholds').addEventListener('click', async () => {
  const values = {};
  Object.keys(DEFAULT_VISION_THRESHOLDS).forEach(key => {
    values[key] = parseFloat(document.getElementById('th-' + key).value);
  });
  await saveVisionThresholds(values);
  currentThresholds = values;
  const saved = document.getElementById('thresholdsSaved');
  saved.textContent = 'Saved ✓';
  setTimeout(() => (saved.textContent = ''), 2000);
  await tick();
});

async function boot() {
  buildSimGrid();
  await loadThresholdsForm();
  await tick();
  setInterval(tick, 8000);
}
boot();
