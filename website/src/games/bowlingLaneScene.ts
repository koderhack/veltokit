import type {PixelColor} from './pixelTypes';
import {PixelContext, hash} from './pixelContext';
import {GRID_HEIGHT, GRID_WIDTH} from './pixelTypes';
import type {BowlingPreviewSimulator, PinLayout} from './bowlingSimulator';
import {
  BALL_LANE_Y,
  BALL_START_Z,
  LANE_SURFACE_Y,
  LANE_WIDTH,
  PIN_HEIGHT,
  PINS_Z,
} from './bowlingSimulator';

const W = GRID_WIDTH;
const H = GRID_HEIGHT;

export type BowlingRenderQuality = 'card' | 'full';

type Proj = {px: number; py: number; scale: number};

/** Kamera za kulą — jak `BowlingGameScene.updateCamera`. */
function project(
  x: number,
  y: number,
  z: number,
  camX: number,
  camY: number,
  camZ: number,
): Proj | null {
  const depth = camZ - z;
  if (depth < 0.4) return null;
  const focal = 112;
  const scale = focal / depth;
  const px = W / 2 + (x - camX) * scale;
  const py = H * 0.78 + (y - camY) * scale * 0.48 - depth * 0.36;
  if (px < -24 || px > W + 24 || py < -8 || py > H + 12) return null;
  return {px, py, scale};
}

function laneWoodColor(x: number, i: number): PixelColor {
  const plank = Math.floor(x / 4) % 2 === 0;
  const grain = (x + i * 3) % 7 === 0;
  if (grain) return 'wood';
  return plank ? 'woodLight' : 'woodDark';
}

/** Lekki renderer na homepage / karty (setki pikseli zamiast dziesiątek tysięcy). */
function renderBowlingCard(
  ctx: PixelContext,
  sim: BowlingPreviewSimulator,
  animTick: number,
): void {
  const cam = sim.camera();

  for (let y = 0; y < H; y++) {
    const t = y / H;
    let band: PixelColor = 'black';
    if (t < 0.22) band = 'black';
    else if (t < 0.42) band = 'navy';
    else if (t < 0.55) band = 'floorB';
    else band = 'floorA';
    ctx.rect(0, y, W, 1, band);
    if (t > 0.4 && t < 0.5 && hash(y + animTick, 3) % 19 === 0) {
      ctx.rect(hash(y, 7) % (W - 2), y, 1, 1, 'white');
    }
  }

  const zSteps = 14;
  for (let i = 0; i < zSteps; i++) {
    const t = i / (zSteps - 1);
    const z = BALL_START_Z + 1 - t * (BALL_START_Z - PINS_Z + 2.5);
    const half = (LANE_WIDTH / 2) * (0.4 + t * 1.05);
    const leftIn = project(-half + 0.06, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    const rightIn = project(half - 0.06, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    const leftOut = project(-half - 0.12, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    const rightOut = project(half + 0.12, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    if (!leftIn || !rightIn) continue;
    const y = Math.round((leftIn.py + rightIn.py) / 2);
    for (let x = Math.round(leftIn.px); x <= Math.round(rightIn.px); x++) {
      if (x >= 0 && x < W) ctx.rect(x, y, 1, 1, laneWoodColor(x, i));
    }
    if (leftOut && leftIn) {
      for (let x = Math.round(leftOut.px); x < Math.round(leftIn.px); x++) {
        if (x >= 0 && x < W) ctx.rect(x, y, 1, 1, 'darkGray');
      }
    }
    if (rightIn && rightOut) {
      for (let x = Math.round(rightIn.px); x <= Math.round(rightOut.px); x++) {
        if (x >= 0 && x < W) ctx.rect(x, y, 1, 1, 'darkGray');
      }
    }
  }

  for (const xSign of [-1, 1] as const) {
    const color: PixelColor = xSign < 0 ? 'magenta' : 'cyan';
    const p = project(xSign * 0.55, 0.1, 0, cam.x, cam.y, cam.z);
    if (p) ctx.rect(Math.round(p.px), Math.round(p.py), 2, 10, color);
  }

  const sortedPins = [...sim.pins].sort((a, b) => b.z - a.z);
  for (const pin of sortedPins) {
    drawPin(ctx, pin, cam);
  }
  drawBall(ctx, sim, cam);
}

function drawSky(ctx: PixelContext, cam: {x: number; y: number; z: number}, animTick: number): void {
  const backZ = PINS_Z - 2.5;
  const top = project(0, 3.2, backZ, cam.x, cam.y, cam.z);
  const bottom = project(0, 0.5, BALL_START_Z + 1, cam.x, cam.y, cam.z);
  if (!top || !bottom) return;
  const y0 = Math.max(0, Math.floor(Math.min(top.py, bottom.py) - 28));
  const y1 = Math.floor(Math.max(top.py, bottom.py) - 8);
  for (let y = y0; y < y1; y++) {
    const t = y / Math.max(1, y1 - y0);
    const band: PixelColor = t < 0.35 ? 'black' : t < 0.55 ? 'navy' : 'navy';
    ctx.rect(0, y, W, 1, band);
    if (t >= 0.55 && hash(Math.floor(y + animTick), 2) % 23 === 0) {
      ctx.rect(hash(y, 1) % (W - 4), y, 1, 1, 'white');
    }
  }
}

function drawFloor(ctx: PixelContext, cam: {x: number; y: number; z: number}): void {
  const corners = [
    project(-5, LANE_SURFACE_Y - 0.04, BALL_START_Z + 2, cam.x, cam.y, cam.z),
    project(5, LANE_SURFACE_Y - 0.04, PINS_Z - 3, cam.x, cam.y, cam.z),
  ];
  if (!corners[0] || !corners[1]) return;
  const y0 = Math.max(0, Math.floor(Math.min(corners[0].py, corners[1].py)));
  const y1 = Math.min(H - 1, Math.floor(Math.max(corners[0].py, corners[1].py)));
  for (let y = y0; y <= y1; y += 2) {
    const c: PixelColor = Math.floor(y / 6) % 2 === 0 ? 'floorA' : 'floorB';
    ctx.rect(0, y, W, 2, c);
  }
}

function drawLaneSurface(ctx: PixelContext, cam: {x: number; y: number; z: number}): void {
  const zSteps = 20;
  for (let i = 0; i < zSteps; i++) {
    const t = i / (zSteps - 1);
    const z = BALL_START_Z + 1.5 - t * (BALL_START_Z - PINS_Z + 3);
    const half = (LANE_WIDTH / 2) * (0.35 + t * 1.15);
    const left = project(-half, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    const right = project(half, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    const leftIn = project(-half + 0.08, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    const rightIn = project(half - 0.08, LANE_SURFACE_Y, z, cam.x, cam.y, cam.z);
    if (!left || !right || !leftIn || !rightIn) continue;
    const y = Math.round((left.py + right.py) / 2);
    for (let x = Math.round(leftIn.px); x <= Math.round(rightIn.px); x++) {
      if (x >= 0 && x < W) ctx.rect(x, y, 1, 1, laneWoodColor(x, i));
    }
    for (let x = Math.round(left.px); x < Math.round(leftIn.px); x++) {
      if (x >= 0 && x < W) ctx.rect(x, y, 1, 1, 'darkGray');
    }
    for (let x = Math.round(rightIn.px); x <= Math.round(right.px); x++) {
      if (x >= 0 && x < W) ctx.rect(x, y, 1, 1, 'darkGray');
    }
  }
}

function drawNeonStrips(
  ctx: PixelContext,
  cam: {x: number; y: number; z: number},
  animTick: number,
): void {
  for (const xSign of [-1, 1] as const) {
    const color: PixelColor = xSign < 0 ? 'magenta' : 'cyan';
    for (let zi = 0; zi < 10; zi++) {
      const z = BALL_START_Z - zi * 1.4;
      const p = project(xSign * 0.62, 0.12, z, cam.x, cam.y, cam.z);
      if (!p || hash(zi, animTick) % 4 === 0) continue;
      ctx.rect(Math.round(p.px), Math.round(p.py), 2, 2, color);
    }
  }
}

function drawBackWall(ctx: PixelContext, cam: {x: number; y: number; z: number}): void {
  const z = PINS_Z - 1.2;
  const top = project(0, 4, z, cam.x, cam.y, cam.z);
  const bottom = project(0, 0, z, cam.x, cam.y, cam.z);
  if (!top || !bottom) return;
  const y0 = Math.max(0, Math.floor(top.py));
  const y1 = Math.min(H - 1, Math.floor(bottom.py));
  for (let y = y0; y <= y1; y += 2) {
    const c: PixelColor = Math.floor(y / 4) % 2 === 0 ? 'darkGray' : 'navy';
    ctx.rect(0, y, W, 2, c);
  }
}

function drawPin(ctx: PixelContext, pin: PinLayout, cam: {x: number; y: number; z: number}): void {
  if (pin.knocked) return;
  const base = project(pin.x, LANE_SURFACE_Y, pin.z, cam.x, cam.y, cam.z);
  if (!base) return;
  const h = Math.max(3, Math.round(base.scale * PIN_HEIGHT * 0.55));
  const w = Math.max(2, Math.round(base.scale * 0.11));
  const px = Math.round(base.px - w / 2);
  const py = Math.round(base.py - h);
  for (let dy = 0; dy < h; dy++) {
    for (let dx = 0; dx < w; dx++) {
      const lx = px + dx;
      const ly = py + dy;
      if (lx < 0 || lx >= W || ly < 0 || ly >= H) continue;
      const bandY = Math.floor((dy / h) * 20);
      const color: PixelColor = bandY >= 9 && bandY <= 12 ? 'red' : 'white';
      ctx.rect(lx, ly, 1, 1, color);
    }
  }
}

function drawBall(
  ctx: PixelContext,
  sim: BowlingPreviewSimulator,
  cam: {x: number; y: number; z: number},
): void {
  const p = project(sim.ballX, BALL_LANE_Y, sim.ballZ, cam.x, cam.y, cam.z);
  if (!p) return;
  const r = Math.max(2, Math.round(p.scale * 0.2));
  const cx = Math.round(p.px);
  const cy = Math.round(p.py);
  for (let dy = -r; dy <= r; dy++) {
    for (let dx = -r; dx <= r; dx++) {
      if (dx * dx + dy * dy > r * r) continue;
      const lx = cx + dx;
      const ly = cy + dy;
      if (lx < 0 || lx >= W || ly < 0 || ly >= H) continue;
      const shine = (lx + ly) % 3 === 0 && dx * dx + dy * dy < (r * 0.6) ** 2;
      ctx.rect(lx, ly, 1, 1, shine ? 'cyan' : 'navy');
    }
  }
}

function renderBowlingFull(
  ctx: PixelContext,
  sim: BowlingPreviewSimulator,
  animTick: number,
): void {
  ctx.rect(0, 0, W, H, 'black');
  const cam = sim.camera();

  drawSky(ctx, cam, animTick);
  drawBackWall(ctx, cam);
  drawFloor(ctx, cam);
  drawLaneSurface(ctx, cam);
  drawNeonStrips(ctx, cam, animTick);

  const sortedPins = [...sim.pins].sort((a, b) => b.z - a.z);
  for (const pin of sortedPins) {
    drawPin(ctx, pin, cam);
  }
  drawBall(ctx, sim, cam);
}

/** Port widoku toru z `BowlingGameScene`. `card` = homepage / siatka gier. */
export function renderBowlingLaneScene(
  ctx: PixelContext,
  sim: BowlingPreviewSimulator,
  animTick: number,
  quality: BowlingRenderQuality = 'card',
): void {
  if (quality === 'card') {
    renderBowlingCard(ctx, sim, animTick);
    return;
  }
  renderBowlingFull(ctx, sim, animTick);
}
