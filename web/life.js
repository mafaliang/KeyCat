// What the cat remembers between runs: how long you have known each other, how close you are,
// and a few counts per day for the 今日小结 card. Only counts are kept, never which keys were
// pressed. The app stores the blob the page posts as `{ memory }` and hands it back with
// `cat.memory(...)` on the next start.
'use strict';
(() => {
  const DAY_FIELDS = ['keys', 'pets', 'petSec', 'napSec', 'pushes', 'breaks', 'focus', 'blinks'];
  const KEEP_DAYS = 35;
  // Bond points needed for each level, and what the level is called.
  const LEVELS = [[0, '刚认识'], [15, '混熟了'], [50, '亲近'], [120, '黏你'], [300, '家人']];
  // Spring Festival (lunar new year) dates; the scarf comes out a few days either side.
  const CNY = ['2026-02-17', '2027-02-06', '2028-01-26', '2029-02-13', '2030-02-03', '2031-01-23', '2032-02-11',
    '2033-01-31', '2034-02-19', '2035-02-08'];

  const pad = n => String(n).padStart(2, '0');
  const dayKey = (d = new Date()) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  const fresh = () => ({ v: 1, firstMet: dayKey(), lastSeen: Date.now(), bond: 0, days: {} });
  let mem = fresh();
  // `loaded` is false until the app has handed over what it saved, so a first save cannot
  // overwrite the real memory with a blank one.
  let loaded = false, dirty = false, lastSave = 0, persist = true;

  const num = v => typeof v === 'number' && isFinite(v) && v >= 0 ? v : 0;

  function today() {
    const k = dayKey();
    if (!mem.days[k]) {
      mem.days[k] = Object.fromEntries(DAY_FIELDS.map(f => [f, 0]));
      const old = Object.keys(mem.days).sort();
      while (old.length > KEEP_DAYS) delete mem.days[old.shift()];
    }
    return mem.days[k];
  }

  function post(message) { window.webkit?.messageHandlers?.cat?.postMessage(message); }

  K.life = {
    dayKey,
    get mem() { return mem; },
    // Takes the saved blob, keeping only fields of the right type.
    load(saved) {
      const m = fresh();
      if (saved && typeof saved === 'object') {
        if (/^\d{4}-\d\d-\d\d$/.test(saved.firstMet)) m.firstMet = saved.firstMet;
        m.lastSeen = num(saved.lastSeen) || m.lastSeen;
        m.bond = num(saved.bond);
        for (const [k, d] of Object.entries(saved.days || {})) {
          if (!/^\d{4}-\d\d-\d\d$/.test(k) || !d || typeof d !== 'object') continue;
          m.days[k] = Object.fromEntries(DAY_FIELDS.map(f => [f, num(d[f])]));
        }
      }
      const previous = loaded ? null : mem;
      mem = m;
      // Anything counted before the memory arrived still counts.
      if (previous) for (const [k, d] of Object.entries(previous.days)) {
        const into = mem.days[k] || (mem.days[k] = Object.fromEntries(DAY_FIELDS.map(f => [f, 0])));
        for (const f of DAY_FIELDS) into[f] += d[f];
      }
      loaded = true;
      return m;
    },
    // Off for a second cat, so only one cat writes the memory.
    setPersist(on) { persist = on; },
    add(field, n = 1) {
      today()[field] += n;
      dirty = true;
    },
    addBond(points) { mem.bond += points; dirty = true; },
    today,
    level() {
      let i = 0;
      while (i + 1 < LEVELS.length && mem.bond >= LEVELS[i + 1][0]) i++;
      const [from, name] = LEVELS[i], next = LEVELS[i + 1]?.[0];
      return { level: i + 1, name, progress: next ? (mem.bond - from) / (next - from) : 1, next };
    },
    daysTogether() {
      const [y, m, d] = mem.firstMet.split('-').map(Number);
      return Math.max(1, Math.floor((Date.now() - new Date(y, m - 1, d).getTime()) / 86400000) + 1);
    },
    // Saves at most once a minute, or at once with `force`.
    tick(force = false) {
      const now = Date.now();
      if (!persist || !loaded || (!dirty && !force) || (!force && now - lastSave < 60000)) return;
      mem.lastSeen = now;
      lastSave = now;
      dirty = false;
      post({ memory: mem });
    },
    // Today's holiday, if any: 'xmas', 'cny', 'halloween', 'birthday' (a year or more since you met).
    festival(date = new Date()) {
      const m = date.getMonth() + 1, d = date.getDate(), key = dayKey(date);
      if (m === 12 && d >= 18 && d <= 26) return 'xmas';
      if ((m === 10 && d >= 29) || (m === 11 && d === 1)) return 'halloween';
      for (const c of CNY) {
        const [y, cm, cd] = c.split('-').map(Number);
        const diff = (date - new Date(y, cm - 1, cd)) / 86400000;
        if (diff >= -3 && diff < 8) return 'cny';
      }
      if (key.slice(5) === mem.firstMet.slice(5) && key !== mem.firstMet) return 'birthday';
      return null;
    },
    winter(date = new Date()) { return [12, 1, 2].includes(date.getMonth() + 1); },
  };
})();
