import {PixelContext} from './pixelContext';
import {renderBowlingLaneScene} from './bowlingLaneScene';
import {getBowlingSim} from './bowlingSimulator';

/** Klatka jak `BowlingGame` + `BowlingGameScene` — tor 3D z kamery za kulą. */
export function renderBowlingFrame(ctx: PixelContext, t: number): void {
  const sim = getBowlingSim();
  sim.update(t);
  const animTick = Math.floor(t * 12);
  renderBowlingLaneScene(ctx, sim, animTick);
}
