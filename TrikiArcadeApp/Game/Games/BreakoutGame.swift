import Foundation
import TrikiMotionKit

final class BreakoutGame: Game {
  let name = "Breakout"
  let inputProfile: GameInputProfile = .breakout

  private struct Brick {
    var x: Int
    var y: Int
    var alive: Bool
  }

  private var paddleX = Double(GameContext.width / 2)
  private var ballX = Double(GameContext.width / 2)
  private var ballY = Double(GameContext.height - 20)
  private var ballVX = 58.0
  private var ballVY = -58.0
  private var bricks: [Brick] = []
  private var lives = 3
  private var gameOver = false
  private var win = false

  private let paddleHalfWidth = 26.0
  private let paddleY = Double(GameContext.height - 8)
  private let ballSize = 2.0
  private let physicsStep = 1.0 / 60.0

  func start(context: GameContext) {
    paddleX = Double(GameContext.width / 2)
    ballX = Double(GameContext.width / 2)
    ballY = Double(GameContext.height - 20)
    ballVX = 58
    ballVY = -58
    lives = 3
    gameOver = false
    win = false
    bricks.removeAll(keepingCapacity: true)

    for row in 0..<4 {
      for col in 0..<8 {
        bricks.append(Brick(
          x: 8 + col * 18,
          y: 10 + row * 7,
          alive: true
        ))
      }
    }
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    guard !gameOver, !win else { return }

    let dt = min(deltaTime, 0.05)
    let minX = paddleHalfWidth
    let maxX = Double(GameContext.width) - paddleHalfWidth
    let centerX = Double(GameContext.width) / 2
    let targetX = centerX + input.posX * 66
    paddleX = min(maxX, max(minX, targetX))

    var remaining = dt
    while remaining > 0 {
      let dt = min(remaining, physicsStep)
      stepBall(dt)
      remaining -= dt
    }
  }

  private func stepBall(_ dt: TimeInterval) {
    ballX += ballVX * dt
    ballY += ballVY * dt

    let maxX = Double(GameContext.width) - ballSize
    if ballX < 0 {
      ballX = 0
      ballVX = abs(ballVX)
    } else if ballX > maxX {
      ballX = maxX
      ballVX = -abs(ballVX)
    }

    if ballY < 0 {
      ballY = 0
      ballVY = abs(ballVY)
    }

    let paddleCollider = GameCollider.centered(
      x: paddleX,
      y: paddleY,
      width: paddleHalfWidth * 2,
      height: 3
    )
    let ballCollider = GameCollider(x: ballX, y: ballY, width: ballSize, height: ballSize)

    if ballVY > 0, ballCollider.overlaps(paddleCollider) {
      let offset = (ballX + ballSize / 2 - paddleX) / paddleHalfWidth
      ballVX = offset * 92
      ballVY = -abs(ballVY)
      ballY = paddleY - ballSize - 0.5
    }

    for idx in bricks.indices where bricks[idx].alive {
      let brick = bricks[idx]
      let brickCollider = GameCollider(
        x: Double(brick.x),
        y: Double(brick.y),
        width: 16,
        height: 5
      )
      if ballCollider.overlaps(brickCollider) {
        bricks[idx].alive = false
        resolveBrickBounce(ball: ballCollider, brick: brickCollider)
        break
      }
    }

    if bricks.allSatisfy({ !$0.alive }) {
      win = true
    }

    if ballY > Double(GameContext.height) {
      lives -= 1
      if lives <= 0 {
        gameOver = true
      } else {
        ballX = paddleX
        ballY = Double(GameContext.height - 20)
        ballVX = 58
        ballVY = -58
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

  func render(context: GameContext) {
    context.rect(x: 0, y: 0, width: GameContext.width, height: GameContext.height, color: .black)
    context.text("BREAKOUT", x: 6, y: 4, color: .white)
    context.text("LIVES \(lives)", x: 105, y: 4, color: .cyan)

    for brick in bricks where brick.alive {
      context.rect(x: brick.x, y: brick.y, width: 16, height: 5, color: .magenta)
    }

    let paddleLeft = floor(paddleX - paddleHalfWidth)
    context.rect(
      x: Int(paddleLeft),
      y: Int(paddleY.rounded(.down)),
      width: Int(paddleHalfWidth * 2),
      height: 3,
      color: .green
    )

    context.rect(
      x: Int(ballX.rounded()),
      y: Int(ballY.rounded()),
      width: Int(ballSize),
      height: Int(ballSize),
      color: .yellow
    )

    if gameOver {
      context.text("GAME OVER", x: 46, y: 44, color: .red)
    } else if win {
      context.text("YOU WIN!", x: 52, y: 44, color: .green)
    }
  }
}
