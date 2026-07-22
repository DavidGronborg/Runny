/* Runny web MVP — GPS run tracking, distance/pace calculations, splits.
   No backend, no integrations: geolocation + localStorage only. */
'use strict';

const $ = (sel) => document.querySelector(sel);

/* ---------------- settings & storage ---------------- */

const settings = {
  get metric() { return localStorage.getItem('runny.metric') !== 'mi'; },
  set metric(v) { localStorage.setItem('runny.metric', v ? 'km' : 'mi'); },
};

const store = {
  load() {
    try { return JSON.parse(localStorage.getItem('runny.runs') || '[]'); }
    catch { return []; }
  },
  save(runs) { localStorage.setItem('runny.runs', JSON.stringify(runs)); },
  add(run) {
    const runs = this.load();
    runs.unshift(run);
    runs.sort((a, b) => b.startDate - a.startDate);
    this.save(runs);
  },
  delete(id) { this.save(this.load().filter((r) => r.id !== id)); },
};

/* ---------------- formatting ---------------- */

const UNIT_M = () => (settings.metric ? 1000 : 1609.344);
const unitLabel = () => (settings.metric ? 'km' : 'mi');

function fmtDuration(seconds) {
  const s = Math.max(0, Math.round(seconds));
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  return h > 0
    ? `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
    : `${m}:${String(sec).padStart(2, '0')}`;
}

function fmtDistance(meters, decimals = 2) {
  return (meters / UNIT_M()).toFixed(decimals);
}

function fmtPace(secPerUnit) {
  if (!isFinite(secPerUnit) || secPerUnit <= 0 || secPerUnit > 5400) return '--:--';
  const s = Math.round(secPerUnit);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

const WEEKDAYS = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];

function runTitle(startDate) {
  const h = new Date(startDate).getHours();
  if (h >= 5 && h < 11) return 'Morning Run';
  if (h >= 11 && h < 14) return 'Lunch Run';
  if (h >= 14 && h < 18) return 'Afternoon Run';
  if (h >= 18 && h < 22) return 'Evening Run';
  return 'Night Run';
}

function fmtShortDate(ts) {
  const d = new Date(ts);
  return `${d.getDate()} ${MONTHS[d.getMonth()].slice(0, 3)} ${d.getFullYear()} · ` +
    `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

/* ---------------- geometry ---------------- */

function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371000, toRad = Math.PI / 180;
  const dLat = (lat2 - lat1) * toRad, dLon = (lon2 - lon1) * toRad;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * toRad) * Math.cos(lat2 * toRad) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/* Splits computed from the recorded points so the km/mi toggle stays free. */
function computeSplits(points) {
  const unit = UNIT_M();
  const last = points[points.length - 1];
  if (!last || last.d <= 0) return [];
  const splits = [];
  let nextMark = unit, lastCross = 0;
  for (let i = 1; i < points.length; i++) {
    const prev = points[i - 1], p = points[i];
    while (prev.d < nextMark && p.d >= nextMark) {
      const frac = (nextMark - prev.d) / Math.max(p.d - prev.d, 0.001);
      const tCross = prev.t + frac * (p.t - prev.t);
      splits.push({ index: splits.length + 1, seconds: tCross - lastCross, meters: unit });
      lastCross = tCross;
      nextMark += unit;
    }
  }
  const remaining = last.d - (nextMark - unit);
  if (remaining > unit * 0.05) {
    splits.push({ index: splits.length + 1, seconds: last.t - lastCross, meters: remaining });
  }
  return splits;
}

/* ---------------- tracker ---------------- */

/* Demo mode accelerates a simulated clock, so the same pipeline (filters,
   pace smoothing, splits) runs against synthetic GPS at 6x speed. */
const clock = {
  simulated: false,
  simTime: 0,
  now() { return this.simulated ? this.simTime : Date.now(); },
};

const tracker = {
  state: 'idle', // idle | running | paused | finished
  distance: 0,
  points: [],        // {lat, lon, t (moving seconds), d (cumulative meters)}
  latlngs: [],
  accuracy: null,
  currentPaceSecPerKm: null,

  startDate: 0,
  accumulatedMs: 0,
  segmentStartMs: null,
  lastFix: null,
  recent: [],
  watchId: null,
  demoTimer: null,
  demoState: null,

  movingSeconds() {
    const extra = this.segmentStartMs != null ? clock.now() - this.segmentStartMs : 0;
    return (this.accumulatedMs + extra) / 1000;
  },

  start(demo) {
    clock.simulated = !!demo;
    clock.simTime = Date.now();
    this.state = 'running';
    this.distance = 0;
    this.points = [];
    this.latlngs = [];
    this.recent = [];
    this.lastFix = null;
    this.accuracy = null;
    this.currentPaceSecPerKm = null;
    this.startDate = Date.now();
    this.accumulatedMs = 0;
    this.segmentStartMs = clock.now();
    if (demo) this.startDemoFeed(); else this.startWatch();
  },

  pause() {
    if (this.state !== 'running') return;
    this.accumulatedMs = this.movingSeconds() * 1000;
    this.segmentStartMs = null;
    this.lastFix = null; // don't count the gap walked while paused
    this.recent = [];
    this.currentPaceSecPerKm = null;
    this.state = 'paused';
  },

  resume() {
    if (this.state !== 'paused') return;
    this.segmentStartMs = clock.now();
    this.state = 'running';
  },

  stop() {
    this.accumulatedMs = this.movingSeconds() * 1000;
    this.segmentStartMs = null;
    this.state = 'finished';
    if (this.watchId != null) navigator.geolocation.clearWatch(this.watchId);
    this.watchId = null;
    if (this.demoTimer) clearInterval(this.demoTimer);
    this.demoTimer = null;
    clock.simulated = false;
    if (this.points.length === 0 || this.distance < 10) return null;
    return {
      id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()),
      startDate: this.startDate,
      duration: this.accumulatedMs / 1000,
      distance: this.distance,
      points: this.points,
    };
  },

  startWatch() {
    this.watchId = navigator.geolocation.watchPosition(
      (pos) => this.processFix(pos.coords.latitude, pos.coords.longitude,
        pos.coords.accuracy, pos.timestamp),
      (err) => showGeoError(err),
      { enableHighAccuracy: true, maximumAge: 1000, timeout: 15000 },
    );
  },

  processFix(lat, lon, accuracy, timestamp) {
    this.accuracy = accuracy;
    if (this.state !== 'running') return;
    if (!(accuracy > 0) || accuracy > 35) return;

    if (this.lastFix) {
      const delta = haversine(this.lastFix.lat, this.lastFix.lon, lat, lon);
      const dt = (timestamp - this.lastFix.timestamp) / 1000;
      if (dt <= 0) return;
      if (delta / dt >= 12) return; // implausible jump (> ~43 km/h)
      this.distance += delta;
    }
    this.lastFix = { lat, lon, timestamp };
    this.latlngs.push([lat, lon]);
    const t = this.movingSeconds();
    this.points.push({ lat, lon, t, d: this.distance });
    this.recent.push({ t, d: this.distance });
    liveMapUpdate(lat, lon);
  },

  updatePace() {
    const now = this.movingSeconds();
    this.recent = this.recent.filter((s) => s.t >= now - 30);
    const first = this.recent[0], last = this.recent[this.recent.length - 1];
    if (!first || !last || last.t - first.t < 5 || last.d - first.d < 8) {
      this.currentPaceSecPerKm = null;
      return;
    }
    this.currentPaceSecPerKm = ((last.t - first.t) / (last.d - first.d)) * 1000;
  },

  /* Demo: a runner looping a park at ~3 m/s with light noise, 6x time-lapse. */
  startDemoFeed() {
    this.demoState = { lat: 55.6761, lon: 12.5683, heading: 0, ts: clock.now() };
    this.demoTimer = setInterval(() => {
      if (this.state === 'running') clock.simTime += 6000;
      const d = this.demoState;
      d.ts = clock.now();
      if (this.state !== 'running') return;
      const speed = 2.8 + 0.5 * Math.sin(clock.simTime / 60000) + Math.random() * 0.2;
      const meters = speed * 6;
      d.heading += 0.045 + (Math.random() - 0.5) * 0.06;
      d.lat += (meters * Math.cos(d.heading)) / 111320;
      d.lon += (meters * Math.sin(d.heading)) / (111320 * Math.cos(d.lat * Math.PI / 180));
      this.processFix(d.lat, d.lon, 5, d.ts);
    }, 1000);
  },
};

/* ---------------- maps ---------------- */

const TILE_URL = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
const TILE_ATTR = '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/attributions">CARTO</a>';

let liveMap = null, livePolyline = null, liveMarker = null;
let summaryMap = null;

function initLiveMap() {
  if (liveMap) {
    livePolyline.setLatLngs([]);
    if (liveMarker) { liveMarker.remove(); liveMarker = null; }
    return;
  }
  liveMap = L.map('live-map', { zoomControl: false, attributionControl: true })
    .setView([55.6761, 12.5683], 15);
  L.tileLayer(TILE_URL, { attribution: TILE_ATTR, maxZoom: 19 }).addTo(liveMap);
  livePolyline = L.polyline([], { color: '#C9F73A', weight: 5, lineCap: 'round', lineJoin: 'round' }).addTo(liveMap);
}

function liveMapUpdate(lat, lon) {
  if (!liveMap) return;
  livePolyline.addLatLng([lat, lon]);
  if (!liveMarker) {
    liveMarker = L.circleMarker([lat, lon], {
      radius: 8, color: '#0B0B0F', weight: 3, fillColor: '#C9F73A', fillOpacity: 1,
    }).addTo(liveMap);
    liveMap.setView([lat, lon], 16);
  } else {
    liveMarker.setLatLng([lat, lon]);
    liveMap.panTo([lat, lon], { animate: true, duration: 0.5 });
  }
}

function renderSummaryMap(points) {
  if (summaryMap) { summaryMap.remove(); summaryMap = null; }
  summaryMap = L.map('summary-map', {
    zoomControl: false, dragging: false, scrollWheelZoom: false,
    doubleClickZoom: false, touchZoom: false, boxZoom: false, keyboard: false,
  });
  L.tileLayer(TILE_URL, { attribution: TILE_ATTR, maxZoom: 19 }).addTo(summaryMap);
  const latlngs = points.map((p) => [p.lat, p.lon]);
  if (latlngs.length > 1) {
    const line = L.polyline(latlngs, { color: '#C9F73A', weight: 4, lineCap: 'round', lineJoin: 'round' }).addTo(summaryMap);
    const mk = (ll, fill) => L.circleMarker(ll, {
      radius: 6, color: '#0B0B0F', weight: 3, fillColor: fill, fillOpacity: 1,
    }).addTo(summaryMap);
    mk(latlngs[0], '#C9F73A');
    mk(latlngs[latlngs.length - 1], '#FFFFFF');
    summaryMap.fitBounds(line.getBounds(), { padding: [30, 30] });
  } else {
    summaryMap.setView([55.6761, 12.5683], 13);
  }
  setTimeout(() => summaryMap.invalidateSize(), 50);
}

/* ---------------- views ---------------- */

const views = ['home', 'history', 'run', 'summary'];

function showView(name) {
  views.forEach((v) => $(`#view-${v}`).classList.toggle('active', v === name));
  $('#tab-bar').style.display = (name === 'run' || name === 'summary') ? 'none' : 'flex';
  $('#tab-home').classList.toggle('active', name === 'home');
  $('#tab-history').classList.toggle('active', name === 'history');
  if (name === 'home') renderHome();
  if (name === 'history') renderHistory();
}

/* ---------------- home ---------------- */

function isThisWeek(ts) {
  const now = new Date();
  const day = (now.getDay() + 6) % 7; // Monday = 0
  const monday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - day);
  return ts >= monday.getTime();
}

function runRowHTML(run) {
  const d = new Date(run.startDate);
  const pace = run.distance > 50 ? run.duration / (run.distance / UNIT_M()) : NaN;
  return `
    <button class="run-row" data-id="${run.id}">
      <span class="run-row-date"><span>${WEEKDAYS[d.getDay()]}</span><b>${d.getDate()}</b></span>
      <span class="run-row-main"><b>${runTitle(run.startDate)}</b><span>${fmtDuration(run.duration)}</span></span>
      <span class="run-row-side">
        <b>${fmtDistance(run.distance)}<i>${unitLabel()}</i></b>
        <span>${fmtPace(pace)} /${unitLabel()}</span>
      </span>
    </button>`;
}

const EMPTY_HOME = `
  <div class="card empty-card">
    <div class="icon">🏃</div>
    <b>No runs yet</b>
    <p class="muted">Hit the volt button below and get moving.</p>
  </div>`;

function renderHome() {
  const now = new Date();
  $('#home-date').textContent = `${now.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })}`.toUpperCase();
  $('#unit-toggle').textContent = unitLabel().toUpperCase();

  const runs = store.load();
  const week = runs.filter((r) => isThisWeek(r.startDate));
  const dist = week.reduce((a, r) => a + r.distance, 0);
  const dur = week.reduce((a, r) => a + r.duration, 0);
  $('#week-distance').textContent = fmtDistance(dist, 1);
  $('#week-unit').textContent = unitLabel();
  $('#week-runs').textContent = week.length;
  $('#week-time').textContent = fmtDuration(dur);
  $('#week-pace').textContent = fmtPace(dist > 50 ? dur / (dist / UNIT_M()) : NaN);

  const list = $('#recent-list');
  list.innerHTML = runs.length ? runs.slice(0, 5).map(runRowHTML).join('') : EMPTY_HOME;
  bindRunRows(list, 'home');
}

/* ---------------- history ---------------- */

function renderHistory() {
  const runs = store.load();
  const list = $('#history-list');
  if (!runs.length) {
    list.innerHTML = `
      <div class="card empty-card">
        <div class="icon">🗓️</div>
        <b>Nothing here yet</b>
        <p class="muted">Your finished runs will show up here.</p>
      </div>`;
    return;
  }
  const groups = new Map();
  runs.forEach((r) => {
    const d = new Date(r.startDate);
    const key = `${d.getFullYear()}-${d.getMonth()}`;
    if (!groups.has(key)) groups.set(key, { year: d.getFullYear(), month: d.getMonth(), runs: [] });
    groups.get(key).runs.push(r);
  });
  list.innerHTML = [...groups.values()].map((g) => {
    const total = g.runs.reduce((a, r) => a + r.distance, 0);
    return `
      <div class="month-header">
        <span class="eyebrow">${MONTHS[g.month]} ${g.year}</span>
        <span class="total">${fmtDistance(total, 1)} ${unitLabel()}</span>
      </div>
      ${g.runs.map(runRowHTML).join('')}`;
  }).join('');
  bindRunRows(list, 'history');
}

function bindRunRows(container, from) {
  container.querySelectorAll('.run-row').forEach((el) => {
    el.addEventListener('click', () => {
      const run = store.load().find((r) => r.id === el.dataset.id);
      if (run) openSummary(run, false, from);
    });
  });
}

/* ---------------- summary / detail ---------------- */

let summaryRun = null;
let summaryIsNew = false;
let summaryFrom = 'home';

function openSummary(run, isNew, from = 'home') {
  summaryRun = run;
  summaryIsNew = isNew;
  summaryFrom = from;
  showView('summary');
  $('#btn-back').classList.toggle('hidden', isNew);

  $('#summary-title').textContent = runTitle(run.startDate);
  $('#summary-date').textContent = fmtShortDate(run.startDate);
  $('#summary-distance').textContent = fmtDistance(run.distance);
  $('#summary-unit').textContent = unitLabel();
  $('#summary-time').textContent = fmtDuration(run.duration);
  const pace = run.distance > 50 ? run.duration / (run.distance / UNIT_M()) : NaN;
  $('#summary-pace').textContent = fmtPace(pace);
  $('#summary-pace-label').textContent = `Avg /${unitLabel()}`;
  const speed = run.duration > 0 ? (run.distance / run.duration) * 3.6 : 0;
  $('#summary-speed').textContent = (settings.metric ? speed : speed / 1.609344).toFixed(1);
  $('#summary-speed-label').textContent = settings.metric ? 'km/h' : 'mph';

  $('#summary-actions').classList.toggle('hidden', !isNew);
  $('#btn-delete').classList.toggle('hidden', isNew);

  renderSplits(run);
  renderSummaryMap(run.points);
}

function renderSplits(run) {
  const splits = computeSplits(run.points);
  const card = $('#splits-card');
  if (!splits.length) { card.classList.add('hidden'); return; }
  card.classList.remove('hidden');
  const unit = UNIT_M();
  const paces = splits.map((s) => s.seconds / (s.meters / unit));
  const fastest = Math.min(...paces);
  $('#splits-list').innerHTML = `
    <div class="splits-head"><span>${unitLabel()}</span><span>Pace</span><span></span></div>
    ${splits.map((s, i) => {
      const pace = paces[i];
      const isFastest = splits.length > 1 && pace <= fastest + 0.5;
      const partial = s.meters < unit * 0.95;
      const width = Math.max(10, (fastest / Math.max(pace, 1)) * 100);
      return `
        <div class="split-row">
          <span class="idx">${partial ? (s.meters / unit).toFixed(1) : s.index}</span>
          <span class="pace${isFastest ? ' fastest' : ''}">${fmtPace(pace)}</span>
          <span class="bar-track"><span class="bar${isFastest ? ' fastest' : ''}" style="display:block;width:${width}%"></span></span>
        </div>`;
    }).join('')}`;
}

/* ---------------- run flow ---------------- */

let uiTimer = null;
let wakeLock = null;

async function acquireWakeLock() {
  try { wakeLock = await navigator.wakeLock?.request('screen'); } catch { /* optional */ }
}

async function startRun(demo) {
  if (!demo && !('geolocation' in navigator)) {
    alert('Geolocation is not supported by this browser.');
    return;
  }
  showView('run');
  initLiveMap();
  setTimeout(() => liveMap.invalidateSize(), 50);
  $('#geo-error').classList.add('hidden');
  $('#run-distance-unit').textContent = unitLabel().toUpperCase();
  $('#run-pace-label').textContent = `Pace /${unitLabel()}`;
  $('#run-split-label').textContent = unitLabel();
  setPausedUI(false);

  // Warm up GPS during the countdown so the first fixes are ready.
  let warmupId = null;
  if (!demo) {
    warmupId = navigator.geolocation.watchPosition(
      (pos) => { tracker.accuracy = pos.coords.accuracy; updateGpsDots(); },
      (err) => showGeoError(err),
      { enableHighAccuracy: true },
    );
  } else {
    tracker.accuracy = 5;
  }

  const overlay = $('#countdown');
  overlay.classList.remove('hidden');
  for (const n of [3, 2, 1]) {
    const el = $('#countdown-number');
    el.textContent = n;
    el.style.animation = 'none';
    void el.offsetWidth; // restart the pop animation
    el.style.animation = '';
    updateGpsDots();
    await new Promise((r) => setTimeout(r, 1000));
  }
  overlay.classList.add('hidden');
  if (warmupId != null) navigator.geolocation.clearWatch(warmupId);

  tracker.start(demo);
  acquireWakeLock();
  uiTimer = setInterval(updateRunUI, 500);
}

function updateGpsDots() {
  const cls = !tracker.accuracy || tracker.accuracy > 35 ? ''
    : tracker.accuracy <= 15 ? 'good' : 'ok';
  ['gps-dot', 'countdown-gps-dot'].forEach((id) => {
    $(`#${id}`).className = `gps-dot ${cls}`;
  });
  $('#countdown-gps-text').textContent = cls === 'good' ? 'GPS locked' : 'Locking GPS…';
}

function updateRunUI() {
  if (tracker.state === 'running') tracker.updatePace();
  $('#run-distance').textContent = fmtDistance(tracker.distance);
  $('#run-time').textContent = fmtDuration(tracker.movingSeconds());
  const pace = tracker.currentPaceSecPerKm != null
    ? tracker.currentPaceSecPerKm * (UNIT_M() / 1000) : NaN;
  $('#run-pace').textContent = fmtPace(pace);
  $('#run-split').textContent = Math.floor(tracker.distance / UNIT_M()) + 1;
  updateGpsDots();
}

function setPausedUI(paused) {
  $('#paused-label').classList.toggle('hidden', !paused);
  $('#btn-pause').classList.toggle('hidden', paused);
  $('#btn-resume').classList.toggle('hidden', !paused);
  $('.run-panel').classList.toggle('paused', paused);
}

function finishRun() {
  clearInterval(uiTimer);
  uiTimer = null;
  wakeLock?.release().catch(() => {});
  wakeLock = null;
  const run = tracker.stop();
  if (!run) {
    showView('home');
    return;
  }
  openSummary(run, true);
}

function showGeoError(err) {
  if (tracker.state === 'running' && err && err.code === err.TIMEOUT) return; // transient
  $('#geo-error-text').textContent = err && err.code === 1
    ? 'Location permission was denied. Allow location access for this site in your browser settings, then try again.'
    : 'Could not get a GPS fix. Make sure location is enabled and you are outdoors.';
  $('#geo-error').classList.remove('hidden');
}

/* ---------------- wire-up ---------------- */

$('#tab-home').addEventListener('click', () => showView('home'));
$('#tab-history').addEventListener('click', () => showView('history'));
$('#btn-start').addEventListener('click', () => startRun(false));
$('#btn-demo').addEventListener('click', () => startRun(true));

$('#unit-toggle').addEventListener('click', () => {
  settings.metric = !settings.metric;
  renderHome();
});

$('#btn-pause').addEventListener('click', () => { tracker.pause(); setPausedUI(true); });
$('#btn-resume').addEventListener('click', () => { tracker.resume(); setPausedUI(false); });
$('#btn-stop').addEventListener('click', () => {
  if (tracker.state === 'paused' || confirm('Finish this run?')) finishRun();
});

$('#btn-save').addEventListener('click', () => {
  if (summaryRun) store.add(summaryRun);
  summaryRun = null;
  showView('home');
});
$('#btn-discard').addEventListener('click', () => {
  if (confirm('Discard this run?')) { summaryRun = null; showView('home'); }
});
$('#btn-delete').addEventListener('click', () => {
  if (summaryRun && confirm('Delete this run?')) {
    store.delete(summaryRun.id);
    summaryRun = null;
    showView(summaryFrom);
  }
});
$('#btn-back').addEventListener('click', () => {
  summaryRun = null;
  showView(summaryFrom);
});
$('#btn-geo-close').addEventListener('click', () => {
  $('#geo-error').classList.add('hidden');
  if (tracker.state !== 'running' && tracker.state !== 'paused') {
    clearInterval(uiTimer);
    showView('home');
  }
});

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible' && (tracker.state === 'running' || tracker.state === 'paused')) {
    acquireWakeLock();
  }
});

window.addEventListener('beforeunload', (e) => {
  if (tracker.state === 'running' || tracker.state === 'paused') {
    e.preventDefault();
    e.returnValue = '';
  }
});

showView('home');
