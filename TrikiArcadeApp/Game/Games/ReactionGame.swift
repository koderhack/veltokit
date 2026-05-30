import Foundation
import TrikiMotionKit

final class SnakeGame: Game {
  let name = "Snake Game"
  let inputProfile: GameInputProfile = .snake
  private let width = GameContext.width
  private let height = GameContext.height
  private var snake: [(x: Int, y: Int)] = []
  private var direction: (dx: Int, dy: Int) = (1, 0)
  private var food: (x: Int, y: Int) = (30, 30)
  private var timer = 0.0
  private var gameOver = false

  func start(context: GameContext) {
    snake = [(40, 45), (39, 45), (38, 45)]
    direction = (1, 0)
    food = (90, 45)
    timer = 0
    gameOver = false
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    guard !gameOver else { return }
    timer += deltaTime

    if input.rotation <= -0.2, direction.dx == 0 {
      direction = (-1, 0)
    } else if input.rotation >= 0.2, direction.dx == 0 {
      direction = (1, 0)
    } else if input.rotation > -0.08, input.rotation < 0.08, direction.dy == 0 {
      direction = (0, -1)
    }

    guard timer >= 0.11 else { return }
    timer = 0

    let next = (
      x: (snake[0].x + direction.dx + width) % width,
      y: (snake[0].y + direction.dy + height) % height
    )
    if snake.contains(where: { $0.x == next.x && $0.y == next.y }) {
      gameOver = true
      return
    }

    snake.insert(next, at: 0)
    if next.x == food.x && next.y == food.y {
      food = (
        x: Int.random(in: 4..<(width - 4)),
        y: Int.random(in: 10..<(height - 4))
      )
    } else {
      _ = snake.popLast()
    }
  }

  func render(context: GameContext) {
    context.rect(x: 0, y: 0, width: GameContext.width, height: GameContext.height, color: .black)
    context.text("SNAKE", x: 6, y: 6, color: .green)
    context.text("LEN \(snake.count)", x: 60, y: 6, color: .white)

    context.rect(x: food.x, y: food.y, width: 2, height: 2, color: .yellow)
    for (idx, part) in snake.enumerated() {
      context.rect(
        x: part.x,
        y: part.y,
        width: 2,
        height: 2,
        color: idx == 0 ? .cyan : .green
      )
    }
    if gameOver {
      context.text("GAME OVER", x: 48, y: 44, color: .red)
    }
  }
}
