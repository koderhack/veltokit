/** Uproszczona symulacja rzutu — te same stałe co `BowlingGameScene`. */

export const LANE_LENGTH = 18;
export const LANE_WIDTH = 1.05;
export const BALL_RADIUS = 0.18;
export const PIN_SPACING = 0.3;
export const PIN_HEIGHT = 0.38;
export const PINS_Z = -7.2;
export const BALL_START_Z = 7.2;
export const LATERAL_RANGE = 0.46;
export const LANE_SURFACE_Y = 0.04;
export const BALL_LANE_Y = LANE_SURFACE_Y + BALL_RADIUS + 0.015;

export type PinLayout = {x: number; z: number; knocked: boolean};

export function buildPinLayout(): PinLayout[] {
  const rows: number[][] = [[0], [-0.5, 0.5], [-1, 0, 1], [-1.5, -0.5, 0.5, 1.5]];
  const pins: PinLayout[] = [];
  for (let row = 0; row < rows.length; row++) {
    const z = PINS_Z + row * PIN_SPACING * 0.86;
    for (const xScale of rows[row]!) {
      pins.push({x: xScale * PIN_SPACING, z, knocked: false});
    }
  }
  return pins;
}

type Phase = 'aiming' | 'rolling' | 'settling';

export class BowlingPreviewSimulator {
  phase: Phase = 'aiming';
  ballX = 0;
  ballZ = BALL_START_Z;
  ballVX = 0;
  ballVZ = 0;
  pins = buildPinLayout();
  rollTime = 0;
  settleTime = 0;
  private throwCooldown = 0;
  private lastT = 0;

  resetPins(): void {
    this.pins = buildPinLayout();
  }

  update(t: number): void {
    const dt = this.lastT > 0 ? Math.min(t - this.lastT, 0.05) : 1 / 60;
    this.lastT = t;
    this.throwCooldown -= dt;

    if (this.phase === 'aiming') {
      this.ballX = Math.sin(t * 1.35) * LATERAL_RANGE * 0.88;
      this.ballZ = BALL_START_Z;
      if (this.throwCooldown <= 0) {
        this.throw(this.ballX / LATERAL_RANGE);
        this.throwCooldown = 4.2;
      }
      return;
    }

    this.rollTime += dt;
    this.ballX += this.ballVX * dt;
    this.ballZ += this.ballVZ * dt;

    const travel = BALL_START_Z - this.ballZ;
    const hookPhase = smoothstep(0.15, 0.82, travel / (LANE_LENGTH * 0.92));
    this.ballVX +=
      Math.sin(t * 4.2) * 0.02 * hookPhase * dt +
      this.ballVX * -0.04 * dt;

    this.resolvePinHits();

    const speed = Math.hypot(this.ballVX, this.ballVZ);
    if (speed < 0.12) {
      this.settleTime += dt;
      if (this.settleTime > 0.45) {
        this.phase = 'aiming';
        this.settleTime = 0;
        this.rollTime = 0;
        this.resetPins();
      }
    } else {
      this.settleTime = 0;
    }

    if (this.rollTime > 2.4 && this.ballZ < PINS_Z + 2) {
      this.phase = 'settling';
    }
  }

  private throw(lateral: number): void {
    this.phase = 'rolling';
    this.rollTime = 0;
    this.settleTime = 0;
    const power = 12;
    const speed = power * 0.9;
    const angle = lateral * 0.08;
    this.ballVX = Math.sin(angle) * speed * 0.1;
    this.ballVZ = -Math.cos(angle) * speed;
  }

  private resolvePinHits(): void {
    if (BALL_START_Z - this.ballZ < 2) return;
    for (const pin of this.pins) {
      if (pin.knocked) continue;
      const dx = this.ballX - pin.x;
      const dz = this.ballZ - pin.z;
      if (Math.hypot(dx, dz) < BALL_RADIUS + 0.064 + 0.02) {
        pin.knocked = true;
        this.ballVX *= 0.35;
        this.ballVZ *= 0.55;
      }
    }
  }

  camera(): {x: number; y: number; z: number} {
    const followX = Math.max(-LANE_WIDTH * 0.55, Math.min(LANE_WIDTH * 0.55, this.ballX * 0.32));
    return {
      x: followX,
      y: BALL_LANE_Y + 1.35,
      z: this.ballZ + 2.4,
    };
  }
}

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = Math.min(1, Math.max(0, (x - edge0) / (edge1 - edge0)));
  return t * t * (3 - 2 * t);
}

let shared: BowlingPreviewSimulator | null = null;

export function getBowlingSim(): BowlingPreviewSimulator {
  if (!shared) shared = new BowlingPreviewSimulator();
  return shared;
}
