// A small animated GIF encoder for 拍一张: one shared palette of up to 256 colours picked by
// median cut, LZW-compressed frames, looping forever. Frames are RGBA ImageData-like arrays,
// already composed over an opaque background.
'use strict';
(() => {
  // Colours are binned at 5 bits per channel to build the palette.
  const binOf = (r, g, b) => (r >> 3) << 10 | (g >> 3) << 5 | (b >> 3);

  function palette(frames) {
    const counts = new Uint32Array(32768);
    for (const f of frames) for (let i = 0; i < f.length; i += 8) counts[binOf(f[i], f[i + 1], f[i + 2])]++;
    const bins = [];
    for (let i = 0; i < counts.length; i++) if (counts[i]) bins.push(i);
    const ch = (bin, c) => (bin >> (10 - 5 * c)) & 31;
    // Split the box with the widest weighted spread until there are 256 boxes (or no more to split).
    let boxes = [bins];
    while (boxes.length < 256) {
      let best = -1, bestScore = 0, bestC = 0;
      boxes.forEach((box, i) => {
        if (box.length < 2) return;
        for (let c = 0; c < 3; c++) {
          let lo = 31, hi = 0, n = 0;
          for (const b of box) { const v = ch(b, c); lo = Math.min(lo, v); hi = Math.max(hi, v); n += counts[b]; }
          const score = (hi - lo) * Math.sqrt(n);
          if (score > bestScore) { bestScore = score; best = i; bestC = c; }
        }
      });
      if (best < 0) break;
      const box = boxes[best].sort((a, b) => ch(a, bestC) - ch(b, bestC));
      let total = 0, half = 0, cut = 1;
      for (const b of box) total += counts[b];
      for (let i = 0; i < box.length - 1; i++) { half += counts[box[i]]; if (half >= total / 2) { cut = i + 1; break; } }
      boxes.splice(best, 1, box.slice(0, cut), box.slice(cut));
    }
    const colors = boxes.map(box => {
      let r = 0, g = 0, b = 0, n = 0;
      for (const bin of box) { const w = counts[bin]; r += ch(bin, 0) * w; g += ch(bin, 1) * w; b += ch(bin, 2) * w; n += w; }
      return [r / n * 8.226, g / n * 8.226, b / n * 8.226].map(v => Math.min(255, Math.round(v)));
    });
    while (colors.length < 256) colors.push([0, 0, 0]);
    // Nearest palette entry per bin, filled in as bins turn up.
    const lookup = new Int16Array(32768).fill(-1);
    const nearest = bin => {
      if (lookup[bin] >= 0) return lookup[bin];
      const r = ch(bin, 0) * 8.226, g = ch(bin, 1) * 8.226, b = ch(bin, 2) * 8.226;
      let best = 0, bestD = Infinity;
      for (let i = 0; i < boxes.length; i++) {
        const c = colors[i], d = (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2;
        if (d < bestD) { bestD = d; best = i; }
      }
      return (lookup[bin] = best);
    };
    return { colors, nearest };
  }

  // Variable-width LZW as GIF wants it, packed into sub-blocks of up to 255 bytes.
  function lzw(indices, out) {
    const MIN = 8, CLEAR = 256, END = 257;
    out.push(MIN);
    const bytes = [];
    let acc = 0, bits = 0, size = MIN + 1;
    const emit = code => {
      acc |= code << bits; bits += size;
      while (bits >= 8) { bytes.push(acc & 255); acc >>>= 8; bits -= 8; }
    };
    let dict = new Map(), next = END + 1;
    emit(CLEAR);
    let prefix = indices[0];
    for (let i = 1; i < indices.length; i++) {
      const k = indices[i], key = prefix << 8 | k;
      const hit = dict.get(key);
      if (hit !== undefined) { prefix = hit; continue; }
      emit(prefix);
      if (next < 4096) {
        dict.set(key, next++);
        if (next > (1 << size) && size < 12) size++;
      } else {
        emit(CLEAR);
        dict = new Map(); next = END + 1; size = MIN + 1;
      }
      prefix = k;
    }
    emit(prefix);
    emit(END);
    if (bits > 0) bytes.push(acc & 255);
    for (let i = 0; i < bytes.length; i += 255) {
      const chunk = bytes.slice(i, i + 255);
      out.push(chunk.length, ...chunk);
    }
    out.push(0);
  }

  K.gif = {
    // `frames`: RGBA byte arrays of w × h; `delay` in hundredths of a second per frame.
    encode(frames, w, h, delay) {
      const { colors, nearest } = palette(frames);
      const out = [];
      const word = v => out.push(v & 255, v >> 8);
      out.push(...[...'GIF89a'].map(c => c.charCodeAt(0)));
      word(w); word(h);
      out.push(0xf7, 0, 0);
      for (const c of colors) out.push(...c);
      // Loop forever.
      out.push(0x21, 0xff, 11, ...[...'NETSCAPE2.0'].map(c => c.charCodeAt(0)), 3, 1, 0, 0, 0);
      for (const f of frames) {
        out.push(0x21, 0xf9, 4, 0x04, delay & 255, delay >> 8, 0, 0);
        out.push(0x2c); word(0); word(0); word(w); word(h); out.push(0);
        const indices = new Uint8Array(w * h);
        for (let i = 0, p = 0; p < indices.length; i += 4, p++) indices[p] = nearest(binOf(f[i], f[i + 1], f[i + 2]));
        lzw(indices, out);
      }
      out.push(0x3b);
      return new Uint8Array(out);
    },
  };
})();
