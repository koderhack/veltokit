/** Tekstury pikselowe — port `BowlingPixelArt` z `BowlingGameScene.swift`. */

export type RGB = [number, number, number];

function fillPattern(
  w: number,
  h: number,
  pattern: (x: number, y: number) => RGB,
): HTMLCanvasElement {
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  if (!ctx) return canvas;
  const img = ctx.createImageData(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const [r, g, b] = pattern(x, y);
      const i = (y * w + x) * 4;
      img.data[i] = r;
      img.data[i + 1] = g;
      img.data[i + 2] = b;
      img.data[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return canvas;
}

export function laneCanvas(): HTMLCanvasElement {
  return fillPattern(32, 32, (x, y) => {
    const plank = Math.floor(x / 4) % 2 === 0;
    const grain = (x + y * 3) % 7 === 0;
    if (grain) return [115, 71, 36];
    return plank ? [184, 122, 66] : [148, 97, 51];
  });
}

export function floorCanvas(): HTMLCanvasElement {
  return fillPattern(24, 24, (x, y) => {
    const c = (Math.floor(x / 6) + Math.floor(y / 6)) % 2 === 0;
    return c ? [26, 28, 46] : [18, 20, 36];
  });
}

export function wallCanvas(): HTMLCanvasElement {
  return fillPattern(28, 28, (x, y) => {
    const brick = (Math.floor(y / 4) % 2 === 0 ? x : x + 2) % 4 < 2;
    return brick ? [41, 46, 71] : [28, 33, 56];
  });
}

export function crowdCanvas(): HTMLCanvasElement {
  const palette: RGB[] = [
    [242, 64, 140],
    [51, 217, 242],
    [242, 217, 51],
    [89, 242, 115],
    [235, 235, 242],
  ];
  return fillPattern(48, 32, (x, y) => {
    if (y % 5 === 0) return [20, 23, 36];
    const pick = (x * 3 + y * 7) % palette.length;
    const head = (x % 6 === 0 || y % 4 === 0) && (x + y) % 3 !== 0;
    return head ? palette[pick]! : [31, 36, 56];
  });
}

export function skyCanvas(): HTMLCanvasElement {
  return fillPattern(64, 32, (x, y) => {
    const t = y / 31;
    if (t < 0.35) return [13, 15, 36];
    if (t < 0.55) return [26, 31, 82];
    const star = (x * 13 + y * 17) % 23 === 0;
    return star ? [242, 242, 255] : [15, 20, 51];
  });
}

export function pinCanvas(): HTMLCanvasElement {
  return fillPattern(8, 20, (x, y) => {
    if (y >= 9 && y <= 12) return [209, 26, 36];
    const shade = (x + y) % 4 === 0;
    return shade ? [240, 240, 240] : [252, 252, 252];
  });
}

export function ballCanvas(): HTMLCanvasElement {
  return fillPattern(8, 8, (x, y) => {
    const dx = x - 3.5;
    const dy = y - 3.5;
    const dist = Math.sqrt(dx * dx + dy * dy);
    if (dist > 3.6) return [20, 64, 166];
    const shine = (x + y) % 3 === 0 && dist < 2.2;
    return shine ? [115, 184, 255] : [31, 107, 235];
  });
}
