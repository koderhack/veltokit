import {PixelContext} from './pixelContext';
import {PongSimulator} from './pongSimulator';

let sim: PongSimulator | null = null;
let lastT = 0;

function getSim(): PongSimulator {
  if (!sim) sim = new PongSimulator();
  return sim;
}

/** Klatka jak `PongGame` — fizyka + render, `posX` z demo inputu. */
export function renderPongFrame(ctx: PixelContext, t: number): void {
  const s = getSim();
  const dt = lastT > 0 ? Math.min(t - lastT, 0.05) : 1 / 60;
  lastT = t;
  const posX = Math.sin(t * 1.35) * 0.92;
  s.update(dt, posX);
  s.render(ctx);
}
