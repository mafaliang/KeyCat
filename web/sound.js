// The purr, made on the fly with Web Audio, so no sound files ship with the app: low rumbling
// noise pulsed about 25 times a second, louder on the out-breath than the in-breath.
// Silent unless the 声音 setting is on.
'use strict';
(() => {
  let ctx = null, out = null;

  function start() {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return false;
    ctx = new Ctx();
    const noise = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate);
    const data = noise.getChannelData(0);
    // Brown noise: deep and soft, unlike the hiss of white noise.
    let last = 0;
    for (let i = 0; i < data.length; i++) {
      last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02;
      data[i] = last * 3.5;
    }
    const src = ctx.createBufferSource();
    src.buffer = noise;
    src.loop = true;
    const low = ctx.createBiquadFilter();
    low.type = 'lowpass';
    low.frequency.value = 420;
    // The pulses: a gain swung between almost nothing and full by a 25 Hz wave.
    const pulse = ctx.createGain();
    pulse.gain.value = 0.55;
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 25;
    const depth = ctx.createGain();
    depth.gain.value = 0.45;
    lfo.connect(depth).connect(pulse.gain);
    out = ctx.createGain();
    out.gain.value = 0;
    src.connect(low).connect(pulse).connect(out).connect(ctx.destination);
    src.start();
    lfo.start();
    return true;
  }

  K.sound = {
    enabled: false,
    volume: 0.6,
    // `level` 0..1 is how hard the cat purrs; `breath` the phase of its breathing, in cycles.
    purr(level, breath) {
      if (!this.enabled || level <= 0.01) {
        if (out) out.gain.setTargetAtTime(0, ctx.currentTime, 0.08);
        return;
      }
      if (!ctx && !start()) return;
      if (ctx.state === 'suspended') ctx.resume().catch(() => {});
      const exhale = 0.6 + 0.4 * Math.max(0, Math.sin(breath * Math.PI * 2));
      out.gain.setTargetAtTime(level * exhale * this.volume * 0.5, ctx.currentTime, 0.06);
    },
  };
})();
