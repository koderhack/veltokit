import {PixelContext} from './pixelContext';
import {
  GRID_HEIGHT,
  GRID_WIDTH,
  PIXEL_TOP_INSET,
} from './pixelTypes';

type Brick = {
  x: number;
  y: number;
  maxHP: number;
  hp: number;
};

/** Port `Games/PongGame.swift` — ta sama fizyka i render. */
export class PongSimulator {
  private paddleX = GRID_WIDTH / 2;
  private ballX = GRID_WIDTH / 2;
  private ballY = GRID_HEIGHT - 20;
  private ballVX = 40;
  private ballVY = -40;
  private bricks: Brick[] = [];
  private score = 0;
  private lives = 5;
  private gameOver = false;
  private win = false;
  private resetTimer = 0;

  private readonly paddleHalfWidth = 26;
  private readonly startingLives = 5;
  private readonly ballSpeed = 40;
  private readonly paddleHitMaxVX = 62;
  private readonly paddleScreenScale = 66;
  private readonly paddleY = GRID_HEIGHT - 8;
  private readonly ballSize = 2;
  private readonly physicsStep = 1 / 60;
  private readonly brickW = 17;
  private readonly brickH = 5;

  constructor() {
    this.restart();
  }

  restart(): void {
    this.score = 0;
    this.lives = this.startingLives;
    this.gameOver = false;
    this.win = false;
    this.resetTimer = 0;
    this.paddleX = GRID_WIDTH / 2;
    this.spawnBricks();
    this.resetBall(true);
  }

  private spawnBricks(): void {
    const rowHP = [1, 1, 2, 2, 3, 3];
    this.bricks = [];
    for (let row = 0; row < rowHP.length; row++) {
      const hp = rowHP[row];
      for (let col = 0; col < 8; col++) {
        this.bricks.push({
          x: 5 + col * 19,
          y: 8 + row * 7,
          maxHP: hp,
          hp,
        });
      }
    }
  }

  /** `posX` z inputu (−1…1), jak w grze. */
  update(deltaTime: number, posX: number): void {
    if (this.gameOver || this.win) {
      this.resetTimer += deltaTime;
      if (this.resetTimer > 2.5) this.restart();
      return;
    }

    const dt = Math.min(deltaTime, 0.05);
    const centerX = GRID_WIDTH / 2;
    const minX = this.paddleHalfWidth;
    const maxX = GRID_WIDTH - this.paddleHalfWidth;
    const targetX = centerX + posX * this.paddleScreenScale;
    this.paddleX = Math.min(maxX, Math.max(minX, targetX));

    let remaining = dt;
    while (remaining > 0) {
      const step = Math.min(remaining, this.physicsStep);
      this.stepBall(step);
      remaining -= step;
    }
  }

  private stepBall(dt: number): void {
    this.ballX += this.ballVX * dt;
    this.ballY += this.ballVY * dt;

    const maxX = GRID_WIDTH - this.ballSize;
    if (this.ballX < 0) {
      this.ballX = 0;
      this.ballVX = Math.abs(this.ballVX);
    } else if (this.ballX > maxX) {
      this.ballX = maxX;
      this.ballVX = -Math.abs(this.ballVX);
    }
    if (this.ballY < 0) {
      this.ballY = 0;
      this.ballVY = Math.abs(this.ballVY);
    }

    const paddleLeft = this.paddleX - this.paddleHalfWidth;
    const paddleRight = this.paddleX + this.paddleHalfWidth;
    const paddleTop = this.paddleY;
    const paddleBottom = this.paddleY + 3;

    if (
      this.ballVY > 0 &&
      this.ballX + this.ballSize > paddleLeft &&
      this.ballX < paddleRight &&
      this.ballY + this.ballSize > paddleTop &&
      this.ballY < paddleBottom
    ) {
      const hitOffset =
        (this.ballX + this.ballSize / 2 - this.paddleX) / this.paddleHalfWidth;
      this.ballVX = hitOffset * this.paddleHitMaxVX;
      this.ballVY = -Math.abs(this.ballVY);
      this.ballY = paddleTop - this.ballSize - 0.5;
    }

    for (let idx = 0; idx < this.bricks.length; idx++) {
      const b = this.bricks[idx];
      if (b.hp <= 0) continue;
      if (
        this.ballX + this.ballSize > b.x &&
        this.ballX < b.x + this.brickW &&
        this.ballY + this.ballSize > b.y &&
        this.ballY < b.y + this.brickH
      ) {
        b.hp -= 1;
        if (b.hp <= 0) {
          this.score += b.maxHP * 30;
        }
        this.resolveBrickBounce(b);
        break;
      }
    }

    if (this.bricks.every((b) => b.hp <= 0)) {
      this.win = true;
      return;
    }

    if (this.ballY > GRID_HEIGHT) {
      this.lives -= 1;
      if (this.lives <= 0) {
        this.gameOver = true;
      } else {
        this.resetBall(true);
      }
    }
  }

  private resolveBrickBounce(brick: Brick): void {
    const overlapLeft = this.ballX + this.ballSize - brick.x;
    const overlapRight = brick.x + this.brickW - this.ballX;
    const overlapTop = this.ballY + this.ballSize - brick.y;
    const overlapBottom = brick.y + this.brickH - this.ballY;
    const minOverlapX = Math.min(overlapLeft, overlapRight);
    const minOverlapY = Math.min(overlapTop, overlapBottom);

    if (minOverlapX < minOverlapY) {
      this.ballVX *= -1;
      this.ballX += this.ballVX > 0 ? minOverlapX + 0.5 : -(minOverlapX + 0.5);
    } else {
      this.ballVY *= -1;
      this.ballY += this.ballVY > 0 ? minOverlapY + 0.5 : -(minOverlapY + 0.5);
    }
  }

  private resetBall(serveFromPaddle: boolean): void {
    this.ballX = serveFromPaddle ? this.paddleX : GRID_WIDTH / 2;
    this.ballY = GRID_HEIGHT - 20;
    this.ballVX = this.ballSpeed;
    this.ballVY = -this.ballSpeed;
  }

  render(ctx: PixelContext): void {
    const top = PIXEL_TOP_INSET;
    ctx.rect(0, 0, GRID_WIDTH, GRID_HEIGHT, 'black');
    ctx.text('PONG', 4, top, 'white');
    ctx.text(`SC ${this.score}`, 42, top, 'yellow');
    ctx.text(`L ${this.lives}`, 118, top, 'cyan');

    for (const brick of this.bricks) {
      if (brick.hp <= 0) continue;
      const color =
        brick.maxHP === 1 ? 'cyan' : brick.maxHP === 2 ? 'yellow' : 'red';
      ctx.rect(brick.x, brick.y, this.brickW, this.brickH, color);
      if (brick.maxHP > 1 && brick.hp < brick.maxHP) {
        ctx.text(String(brick.hp), brick.x + 6, brick.y, 'white');
      }
    }

    const paddleLeft = Math.round(this.paddleX - this.paddleHalfWidth);
    ctx.rect(paddleLeft, Math.floor(this.paddleY), this.paddleHalfWidth * 2, 3, 'green');
    ctx.rect(
      Math.floor(this.ballX),
      Math.floor(this.ballY),
      this.ballSize,
      this.ballSize,
      'yellow',
    );

    if (this.gameOver) {
      ctx.text('GAME OVER', 46, 44, 'red');
    } else if (this.win) {
      ctx.text('WYGRANA!', 52, 44, 'green');
    }
  }
}
