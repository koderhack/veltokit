import type {PixelColor} from './pixelTypes';
import {PixelContext, hash} from './pixelContext';
import {GRID_HEIGHT, GRID_WIDTH} from './pixelTypes';

const w = GRID_WIDTH;
const h = GRID_HEIGHT;

type Side = 'left' | 'right';

/** Port `Games/DartArenaScene.swift` */
export function renderDartArena(
  ctx: PixelContext,
  boardCenterX: number,
  boardCenterY: number,
  boardRadius: number,
  animTick: number,
): void {
  fillBackground(ctx);
  drawBackWall(ctx, boardCenterX, boardCenterY, boardRadius);
  drawCeiling(ctx, boardCenterX, animTick);
  drawSpotlights(ctx, boardCenterX, boardCenterY);
  drawSideStands(ctx, 'left', animTick);
  drawSideStands(ctx, 'right', animTick);
  drawFloor(ctx, boardCenterX, boardCenterY, boardRadius);
  drawBoardGlow(ctx, boardCenterX, boardCenterY, boardRadius);
}

function fillBackground(ctx: PixelContext): void {
  ctx.rect(0, 0, w, h, 'black');
  for (let y = 0; y < h; y++) {
    const t = y / (h - 1);
    const band: PixelColor = y < 12 ? 'black' : t < 0.55 ? 'navy' : 'road';
    ctx.rect(0, y, w, 1, band);
  }
}

function drawBackWall(
  ctx: PixelContext,
  boardCenterX: number,
  boardCenterY: number,
  boardRadius: number,
): void {
  const wallBottom = Math.floor(boardCenterY - boardRadius - 4);
  if (wallBottom <= 8) return;
  for (let y = 8; y < wallBottom; y++) {
    for (let x = 0; x < w; x++) {
      const dx = Math.abs(x - boardCenterX) / boardCenterX;
      const shade: PixelColor = hash(x, y) % 5 === 0 ? 'navy' : 'darkGray';
      const depth = 1 - (y / wallBottom) * 0.35;
      if (dx < 0.92 * depth) {
        ctx.rect(x, y, 1, 1, shade);
      }
    }
  }
  ctx.rect(0, wallBottom, w, 2, 'wood');
}

function drawCeiling(ctx: PixelContext, boardCenterX: number, animTick: number): void {
  for (let x = 0; x < w; x += 18) {
    ctx.rect(x, 2, 1, 6, 'darkGray');
    ctx.rect(x, 8, 14, 1, 'darkGray');
  }
  const flicker = Math.floor(animTick / 18) % 2 === 0;
  for (const lx of [24, 56, 80, 104, 132]) {
    const glow: PixelColor =
      flicker && hash(lx, animTick) % 3 === 0 ? 'yellow' : 'white';
    ctx.rect(lx, 4, 3, 2, glow);
    ctx.rect(lx + 1, 6, 1, 1, 'yellow');
  }
  ctx.rect(Math.round(boardCenterX) - 2, 3, 5, 2, 'cyan');
}

function drawSpotlights(
  ctx: PixelContext,
  boardCenterX: number,
  boardCenterY: number,
): void {
  const targetY = Math.round(boardCenterY);
  const targetX = Math.round(boardCenterX);
  for (const originX of [12, 148]) {
    drawLightBeam(ctx, originX, 6, targetX, targetY, 'cyan');
  }
  drawLightBeam(ctx, Math.round(boardCenterX), 4, targetX, targetY, 'yellow');
}

function drawLightBeam(
  ctx: PixelContext,
  fromX: number,
  fromY: number,
  toX: number,
  toY: number,
  color: PixelColor,
): void {
  const steps = Math.max(Math.abs(toX - fromX), Math.abs(toY - fromY));
  if (steps <= 0) return;
  for (let i = 0; i < steps; i += 2) {
    const t = i / steps;
    const x = fromX + Math.floor((toX - fromX) * t);
    const y = fromY + Math.floor((toY - fromY) * t);
    if (hash(x, y) % 4 !== 0) continue;
    ctx.rect(x, y, 1, 1, color);
  }
}

function drawSideStands(ctx: PixelContext, side: Side, animTick: number): void {
  const rows = 10;
  for (let row = 0; row < rows; row++) {
    const depth = row;
    const y = 12 + row * 6;
    if (y >= h - 14) continue;
    const tierWidth = 38 - depth * 2;
    const x0 = side === 'left' ? 1 + depth : w - tierWidth - 1 - depth;
    ctx.rect(x0, y - 1, tierWidth, 1, 'wood');
    ctx.rect(x0, y + 4, tierWidth, 1, 'white');
    for (let col = 0; col < tierWidth; col++) {
      const x = x0 + col;
      if (shouldDrawCrowdPixel(x, y, row, col, animTick)) {
        ctx.rect(x, y, 1, 1, crowdColor(x, y, animTick));
        if (row > 2 && hash(x, y + 1) % 3 === 0) {
          ctx.rect(x, y + 1, 1, 1, 'darkGray');
        }
      }
    }
  }
  const pillarX = side === 'left' ? 42 : 115;
  for (let py = 10; py < h - 12; py++) {
    if (py % 7 === 0) continue;
    ctx.rect(pillarX, py, 2, 1, 'wood');
  }
}

function shouldDrawCrowdPixel(
  x: number,
  y: number,
  row: number,
  col: number,
  animTick: number,
): boolean {
  const wave = Math.floor(animTick / 6 + row);
  const base = hash(x + wave, y) % 10;
  if (base < 2) return false;
  const cheer = (animTick + col) % 24 < 4;
  return cheer ? base < 9 : base < 7;
}

function crowdColor(x: number, y: number, animTick: number): PixelColor {
  const palette: PixelColor[] = ['cyan', 'magenta', 'yellow', 'green', 'red', 'white'];
  return palette[hash(x + Math.floor(animTick / 10), y) % palette.length];
}

function drawFloor(
  ctx: PixelContext,
  boardCenterX: number,
  boardCenterY: number,
  boardRadius: number,
): void {
  const floorTop = Math.round(boardCenterY + boardRadius + 2);
  if (floorTop >= h - 2) return;
  const vanishX = boardCenterX;

  for (let y = floorTop; y < h; y++) {
    const t = (y - floorTop) / (h - floorTop);
    const halfWidth = 12 + t * 78;
    const left = Math.floor(vanishX - halfWidth);
    const right = Math.floor(vanishX + halfWidth);
    for (let x = Math.max(0, left); x <= Math.min(w - 1, right); x++) {
      const u = (x - left) / Math.max(1, right - left);
      const plank = Math.floor(u * 14) % 2 === 0;
      const shade: PixelColor = plank ? 'wood' : 'road';
      if (hash(x, y) % 11 === 0) {
        ctx.rect(x, y, 1, 1, 'darkGray');
      } else {
        ctx.rect(x, y, 1, 1, shade);
      }
    }
    if (y % 5 === 0) {
      const lineLeft = Math.floor(vanishX - halfWidth * 0.92);
      const lineRight = Math.floor(vanishX + halfWidth * 0.92);
      ctx.rect(Math.max(0, lineLeft), y, Math.max(1, lineRight - lineLeft), 1, 'black');
    }
  }
  ctx.rect(0, floorTop, w, 1, 'yellow');
}

function drawBoardGlow(
  ctx: PixelContext,
  boardCenterX: number,
  boardCenterY: number,
  boardRadius: number,
): void {
  const cx = Math.round(boardCenterX);
  const cy = Math.round(boardCenterY);
  const r = Math.ceil(boardRadius) + 3;
  for (let py = cy - r; py <= cy + r; py++) {
    for (let px = cx - r; px <= cx + r; px++) {
      const dx = px - cx;
      const dy = py - cy;
      const d = Math.sqrt(dx * dx + dy * dy);
      if (d > boardRadius && d < boardRadius + 3.5 && hash(px, py) % 2 === 0) {
        ctx.rect(px, py, 1, 1, 'yellow');
      }
    }
  }
}
