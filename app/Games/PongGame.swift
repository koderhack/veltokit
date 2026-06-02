import Foundation
import VeltoKit

/// Pong: żyro, klocki wielopoziomowe, punkty, dźwięk.
final class PongGame: Game {
  /// Przechowuje wartość `name` wykorzystywaną przez dany komponent.
  let name = "Pong"
  /// Przechowuje wartość `inputProfile` wykorzystywaną przez dany komponent.
  let inputProfile: GameInputProfile = .pong

  private struct Brick {
    let x: Int
    let y: Int
    let maxHP: Int
    var hp: Int

    var alive: Bool { hp > 0 }

    var color: PixelColor {
      switch maxHP {
      case 1: return .cyan
      case 2: return .yellow
      default: return .red
      }
    }

    var points: Int { maxHP * 30 }
  }

  private var paddleX = Double(GameContext.width / 2)
  private var ballX = Double(GameContext.width / 2)
  private var ballY = Double(GameContext.height - 20)
  private var ballVX = 40.0
  private var ballVY = -40.0
  private var bricks: [Brick] = []
  private var score = 0
  private var lives = 5
  private var gameOver = false
  private var win = false

  private let paddleHalfWidth = 26.0
  private let startingLives = 5
  private let ballSpeed = 40.0
  private let paddleHitMaxVX = 62.0
  /// smoothX × scale → offset od środka (160 px pole ≈ 66 px przy |smooth|≈1).
  private let paddleScreenScale = 66.0
  private let paddleY = Double(GameContext.height - 8)
  private let ballSize = 2.0
  private let physicsStep = 1.0 / 60.0
  private let brickW = 17
  private let brickH = 5

  /// Wykonuje operację `start` w bieżącym kontekście gry/UI.
  func start(context: GameContext) {
    score = 0
    lives = startingLives
    gameOver = false
    win = false
    paddleX = Double(GameContext.width / 2)
    spawnBricks()
    resetBall(serveFromPaddle: true)
  }

  private func spawnBricks() {
    bricks.removeAll(keepingCapacity: true)
    let rowHP = [1, 1, 2, 2, 3, 3]
    for (row, hp) in rowHP.enumerated() {
      for col in 0..<8 {
        bricks.append(
          Brick(
            x: 5 + col * 19,
            y: 8 + row * 7,
            maxHP: hp,
            hp: hp
          )
        )
      }
    }
  }

  /// Wykonuje operację `update` w bieżącym kontekście gry/UI.
  func update(input: GameInput, deltaTime: TimeInterval) {
    guard !gameOver, !win else { return }
    let dt = min(deltaTime, 0.05)
    let centerX = Double(GameContext.width) / 2
    let minX = paddleHalfWidth
    let maxX = Double(GameContext.width) - paddleHalfWidth
    let targetX = centerX + input.posX * paddleScreenScale
    paddleX = min(maxX, max(minX, targetX))

    var remaining = dt
    while remaining > 0 {
      let step = min(remaining, physicsStep)
      stepBall(step)
      remaining -= step
    }
  }

  private func stepBall(_ dt: TimeInterval) {
    ballX += ballVX * dt
    ballY += ballVY * dt

    let maxX = Double(GameContext.width) - ballSize
    if ballX < 0 {
      ballX = 0
      ballVX = abs(ballVX)
      GameSFX.wallHit()
    } else if ballX > maxX {
      ballX = maxX
      ballVX = -abs(ballVX)
      GameSFX.wallHit()
    }
    if ballY < 0 {
      ballY = 0
      ballVY = abs(ballVY)
      GameSFX.wallHit()
    }

    let paddleCollider = GameCollider.centered(
      x: paddleX,
      y: paddleY,
      width: paddleHalfWidth * 2,
      height: 3
    )
    let ballCollider = GameCollider(x: ballX, y: ballY, width: ballSize, height: ballSize)

    if ballVY > 0, ballCollider.overlaps(paddleCollider) {
      let hitOffset = (ballX + ballSize / 2 - paddleX) / paddleHalfWidth
      ballVX = hitOffset * paddleHitMaxVX
      ballVY = -abs(ballVY)
      ballY = paddleY - ballSize - 0.5
      GameSFX.paddleHit()
    }

    for idx in bricks.indices where bricks[idx].alive {
      let b = bricks[idx]
      let brickCollider = GameCollider(
        x: Double(b.x),
        y: Double(b.y),
        width: Double(brickW),
        height: Double(brickH)
      )
      guard ballCollider.overlaps(brickCollider) else { continue }

      bricks[idx].hp -= 1
      if bricks[idx].alive {
        GameSFX.brickHit(level: b.maxHP)
      } else {
        score += b.points
        GameSFX.brickBreak()
      }
      resolveBrickBounce(ball: ballCollider, brick: brickCollider)
      break
    }

    if bricks.allSatisfy({ !$0.alive }) {
      win = true
      GameSFX.win()
    }

    if ballY > Double(GameContext.height) {
      lives -= 1
      GameSFX.lifeLost()
      if lives <= 0 {
        gameOver = true
      } else {
        resetBall(serveFromPaddle: true)
      }
    }
  }

  private func resolveBrickBounce(ball: GameCollider, brick: GameCollider) {
    let overlapLeft = ball.x + ball.width - brick.x
    let overlapRight = brick.x + brick.width - ball.x
    let overlapTop = ball.y + ball.height - brick.y
    let overlapBottom = brick.y + brick.height - ball.y
    let minOverlapX = min(overlapLeft, overlapRight)
    let minOverlapY = min(overlapTop, overlapBottom)

    if minOverlapX < minOverlapY {
      ballVX *= -1
      ballX += ballVX > 0 ? minOverlapX + 0.5 : -(minOverlapX + 0.5)
    } else {
      ballVY *= -1
      ballY += ballVY > 0 ? minOverlapY + 0.5 : -(minOverlapY + 0.5)
    }
  }

  private func resetBall(serveFromPaddle: Bool) {
    ballX = serveFromPaddle ? paddleX : Double(GameContext.width / 2)
    ballY = Double(GameContext.height - 20)
    ballVX = ballSpeed
    ballVY = -ballSpeed
  }

  /// Wykonuje operację `render` w bieżącym kontekście gry/UI.
  func render(context: GameContext) {
    let top = GameContext.pixelTopInset
    context.rect(x: 0, y: 0, width: GameContext.width, height: GameContext.height, color: .black)
    context.text("PONG", x: 4, y: top, color: .white)
    context.text("SC \(score)", x: 42, y: top, color: .yellow)
    context.text("L \(lives)", x: 118, y: top, color: .cyan)

    for brick in bricks where brick.alive {
      context.rect(x: brick.x, y: brick.y, width: brickW, height: brickH, color: brick.color)
      if brick.maxHP > 1, brick.hp < brick.maxHP {
        context.text("\(brick.hp)", x: brick.x + 6, y: brick.y, color: .white)
      }
    }

    let paddleLeft = Int((paddleX - paddleHalfWidth).rounded(.toNearestOrAwayFromZero))
    context.rect(
      x: paddleLeft,
      y: Int(paddleY.rounded(.down)),
      width: Int(paddleHalfWidth * 2),
      height: 3,
      color: .green
    )
    context.rect(
      x: Int(floor(ballX)),
      y: Int(floor(ballY)),
      width: Int(ballSize),
      height: Int(ballSize),
      color: .yellow
    )

    if gameOver {
      context.text("GAME OVER", x: 46, y: 44, color: .red)
    } else if win {
      context.text("WYGRANA!", x: 52, y: 44, color: .green)
    }
  }
}
