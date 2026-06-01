import type {PixelColor} from './pixelTypes';
import {PixelContext} from './pixelContext';
import {GRID_WIDTH, PIXEL_TOP_INSET} from './pixelTypes';

export const DART_BOARD_RADIUS = 35;
export const DART_CENTER_X = GRID_WIDTH / 2;
export const DART_CENTER_Y = PIXEL_TOP_INSET + DART_BOARD_RADIUS + 6;

export const SEGMENT_VALUES = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];

export function sectorIndex(dx: number, dy: number): number {
  const angle = Math.atan2(dy, dx);
  let angle01 = (angle + Math.PI / 2) / (2 * Math.PI);
  if (angle01 < 0) angle01 += 1;
  if (angle01 >= 1) angle01 -= 1;
  return Math.min(19, Math.max(0, Math.floor(angle01 * 20)));
}

export function drawSegmentNumbers(
  ctx: PixelContext,
  centerX: number,
  centerY: number,
  boardRadius: number,
): void {
  const labelR = boardRadius * 0.76;
  for (let sector = 0; sector < 20; sector++) {
    const value = SEGMENT_VALUES[sector];
    const angle = ((sector + 0.5) / 20) * (Math.PI * 2) - Math.PI / 2;
    const x = centerX + labelR * Math.cos(angle);
    const y = centerY + labelR * Math.sin(angle);
    const label = String(value);
    const tx = Math.round(x) - (label.length > 1 ? 5 : 2);
    const ty = Math.round(y) - 3;
    const color: PixelColor = sector % 2 === 0 ? 'black' : 'yellow';
    ctx.text(label, tx, ty, color);
  }
  const bullY = Math.round(centerY) - 3;
  const bullX = Math.round(centerX) - 5;
  ctx.text('25', bullX, bullY, 'white');
}

export function boardPixelColor(
  dx: number,
  dy: number,
  distance: number,
  boardRadius: number,
): PixelColor {
  const bullInnerR = (boardRadius * 5) / 45;
  const bullOuterR = (boardRadius * 10) / 45;
  const tripleInnerR = (boardRadius * 25) / 45;
  const tripleOuterR = (boardRadius * 30) / 45;
  const doubleInnerR = (boardRadius * 40) / 45;
  const doubleOuterR = boardRadius;

  if (distance < bullInnerR) return 'red';
  if (distance < bullOuterR) return 'green';
  if (distance >= tripleInnerR && distance < tripleOuterR) return 'red';
  if (distance >= doubleInnerR && distance < doubleOuterR) return 'green';

  const sector = sectorIndex(dx, dy);
  return sector % 2 === 0 ? 'white' : 'darkGray';
}

export function drawBoard(
  ctx: PixelContext,
  centerX: number,
  centerY: number,
  boardRadius: number,
): void {
  const cx = Math.round(centerX);
  const cy = Math.round(centerY);
  const rMax = Math.ceil(boardRadius);

  for (let py = cy - rMax; py <= cy + rMax; py++) {
    if (py < PIXEL_TOP_INSET || py >= 90) continue;
    for (let px = cx - rMax; px <= cx + rMax; px++) {
      if (px < 0 || px >= GRID_WIDTH) continue;
      const dx = px - cx;
      const dy = py - cy;
      const dist = Math.sqrt(dx * dx + dy * dy);
      if (dist > boardRadius) continue;
      const color = boardPixelColor(dx, dy, dist, boardRadius);
      ctx.rect(px, py, 1, 1, color);
    }
  }
}
