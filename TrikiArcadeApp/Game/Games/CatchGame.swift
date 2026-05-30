import Foundation
import TrikiMotionKit

final class CatchGame: Game {
  let name = "Catch Game"
  let inputProfile: GameInputProfile = .catchGame

  private var basketX = Double(GameContext.width / 2)
  private var objectX = Double(GameContext.width / 2)
  private var objectY = 0.0
  private var score = 0
  private var misses = 0

  private let basketHalfWidth = 12.0
  private let basketY = Double(GameContext.height - 8)

  func start(context: GameContext) {
    basketX = Double(GameContext.width / 2)
    score = 0
    misses = 0
    respawnObject()
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    let dt = min(deltaTime, 0.05)

    let minX = basketHalfWidth
    let maxX = Double(GameContext.width) - basketHalfWidth
    let targetX = MotionControls.screenX(
      posX: input.posX,
      width: Double(GameContext.width)
    )
    basketX = min(maxX, max(minX, targetX))

    objectY += 85 * dt
    if objectY >= basketY {
      let caught = abs(objectX - basketX) <= basketHalfWidth
      if caught {
        score += 1
      } else {
        misses += 1
      }
      respawnObject()
    }
  }

  func render(context: GameContext) {
    context.rect(x: 0, y: 0, width: GameContext.width, height: GameContext.height, color: .black)
    context.text("CATCH", x: 6, y: 4, color: .white)
    context.text("S \(score)  M \(misses)", x: 92, y: 4, color: .cyan)

    let basketLeft = floor(basketX - basketHalfWidth)
    context.rect(
      x: Int(basketLeft),
      y: Int(basketY.rounded(.down)),
      width: Int(basketHalfWidth * 2),
      height: 3,
      color: .green
    )

    context.rect(
      x: Int(objectX.rounded()),
      y: Int(objectY.rounded()),
      width: 3,
      height: 3,
      color: .yellow
    )
  }

  private func respawnObject() {
    objectX = Double(Int.random(in: 4..<(GameContext.width - 4)))
    objectY = 10
  }
}
