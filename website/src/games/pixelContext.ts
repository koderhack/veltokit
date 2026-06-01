import type {DrawCommand, PixelColor} from './pixelTypes';
import {GRID_HEIGHT, GRID_WIDTH} from './pixelTypes';

export class PixelContext {
  commands: DrawCommand[] = [];

  clear(): void {
    this.commands = [];
  }

  rect(x: number, y: number, width: number, height: number, color: PixelColor = 'white'): void {
    this.commands.push({type: 'rect', x, y, width, height, color});
  }

  text(value: string, x: number, y: number, color: PixelColor = 'white'): void {
    this.commands.push({type: 'text', value, x, y, color});
  }

  fill(color: PixelColor): void {
    this.rect(0, 0, GRID_WIDTH, GRID_HEIGHT, color);
  }
}

export function hash(a: number, b: number): number {
  let x = (Math.imul(a | 0, 374761393) + Math.imul(b | 0, 668265263)) >>> 0;
  x = Math.imul(x ^ (x >>> 13), 1274126171) >>> 0;
  return x % 9999;
}
