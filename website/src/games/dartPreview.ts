import {PixelContext} from './pixelContext';
import {GRID_HEIGHT, GRID_WIDTH, PIXEL_TOP_INSET} from './pixelTypes';
import {renderDartArena} from './dartArenaScene';
import {
  DART_BOARD_RADIUS,
  DART_CENTER_X,
  DART_CENTER_Y,
  drawBoard,
  drawSegmentNumbers,
} from './dartBoardLayout';

type Marker = {x: number; y: number};

let markers: Marker[] = [];
let flightStart = -1;
let flightFrom = {x: 0, y: 0};
let flightTo = {x: 0, y: 0};
let lastThrowCycle = -1;

/** Klatka jak `DartGame.render` — arena, cel, lot, markery. */
export function renderDartFrame(ctx: PixelContext, t: number): void {
  const animTick = Math.floor(t * 12);
  const cx = DART_CENTER_X;
  const cy = DART_CENTER_Y;
  const r = DART_BOARD_RADIUS;

  const aimX = cx + Math.sin(t * 1.25) * 14;
  const aimY = cy + Math.cos(t * 0.85) * 9;

  const throwCycle = Math.floor(t / 3.8);
  if (throwCycle !== lastThrowCycle) {
    lastThrowCycle = throwCycle;
    flightStart = t;
    flightFrom = {x: aimX, y: cy + r * 0.55};
    const angle = (throwCycle * 0.7) % (Math.PI * 2);
    flightTo = {
      x: cx + Math.cos(angle) * r * 0.55,
      y: cy + Math.sin(angle) * r * 0.55,
    };
  }

  renderDartArena(ctx, cx, cy, r, animTick);
  drawBoard(ctx, cx, cy, r);
  drawSegmentNumbers(ctx, cx, cy, r);

  for (const m of markers) {
    drawDartTip(ctx, m.x, m.y, 'yellow');
  }

  const flightDur = 0.45;
  if (flightStart >= 0) {
    const p = Math.min(1, (t - flightStart) / flightDur);
    if (p < 1) {
      const ease = 1 - (1 - p) ** 2;
      const fx = flightFrom.x + (flightTo.x - flightFrom.x) * ease;
      const fy = flightFrom.y + (flightTo.y - flightFrom.y) * ease;
      drawDartTip(ctx, fx, fy, 'white');
    } else if (p >= 1 && p < 1.05) {
      markers = [...markers.slice(-2), {x: flightTo.x, y: flightTo.y}];
      flightStart = -1;
    }
  }

  if (flightStart < 0) {
    drawDartTip(ctx, aimX, aimY, 'white');
    if (Math.sin(t * 0.65) > 0.2) {
      drawDartTip(ctx, cx - 5, cy + r * 0.52, 'yellow');
    }
  }
}

function drawDartTip(
  ctx: PixelContext,
  x: number,
  y: number,
  color: import('./pixelTypes').PixelColor,
): void {
  const px = Math.round(x);
  const py = Math.round(y);
  for (let ox = -1; ox <= 1; ox++) {
    for (let oy = -1; oy <= 1; oy++) {
      const gx = px + ox;
      const gy = py + oy;
      if (gx >= 0 && gx < GRID_WIDTH && gy >= PIXEL_TOP_INSET && gy < GRID_HEIGHT) {
        ctx.rect(gx, gy, 1, 1, color);
      }
    }
  }
}
