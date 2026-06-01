import {useEffect, useRef} from 'react';
import type {DrawCommand} from '@site/src/games/pixelTypes';
import {PIXEL_PALETTE, GRID_HEIGHT, GRID_WIDTH} from '@site/src/games/pixelTypes';

type Props = {
  commands: DrawCommand[];
  className?: string;
};

/** Odpowiednik `UI/PixelCanvas.swift` — nearest-neighbor 160×90 */
export default function PixelCanvas({commands, className}: Props): JSX.Element {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const parent = canvas.parentElement;
    if (!parent) return;

    const dpr = window.devicePixelRatio || 1;
    const rect = parent.getBoundingClientRect();
    const scale = Math.max(1, Math.floor(Math.min(rect.width / GRID_WIDTH, rect.height / GRID_HEIGHT)));
    const cw = GRID_WIDTH * scale;
    const ch = GRID_HEIGHT * scale;

    canvas.width = cw * dpr;
    canvas.height = ch * dpr;
    canvas.style.width = `${cw}px`;
    canvas.style.height = `${ch}px`;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.imageSmoothingEnabled = false;

    ctx.fillStyle = PIXEL_PALETTE.black;
    ctx.fillRect(0, 0, cw, ch);

    const sx = scale;
    const sy = scale;
    const fontSize = Math.max(8, scale * 0.85);

    for (const cmd of commands) {
      if (cmd.type === 'rect') {
        ctx.fillStyle = PIXEL_PALETTE[cmd.color];
        ctx.fillRect(cmd.x * sx, cmd.y * sy, cmd.width * sx, cmd.height * sy);
      } else {
        ctx.fillStyle = PIXEL_PALETTE[cmd.color];
        ctx.font = `bold ${fontSize}px "JetBrains Mono", ui-monospace, monospace`;
        ctx.textBaseline = 'top';
        ctx.fillText(cmd.value, cmd.x * sx, cmd.y * sy);
      }
    }
  }, [commands]);

  return (
    <canvas
      ref={canvasRef}
      className={className}
      aria-hidden
      style={{display: 'block', margin: '0 auto'}}
    />
  );
}
