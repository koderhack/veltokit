import Foundation
import TrikiMotionKit

final class ReactionTiltGame: Game {
  let name = "Reaction Game"
  let inputProfile: GameInputProfile = .reactionTilt

  private enum TargetDirection: String {
    case left = "LEFT"
    case right = "RIGHT"
  }

  private var target: TargetDirection = .left
  private var roundTimer = 0.0
  private var reactionTime = 0.0
  private var successCount = 0
  private var failCount = 0
  private var awaitingInput = false
  private var resultLabel = "WAIT..."

  func start(context: GameContext) {
    successCount = 0
    failCount = 0
    scheduleNextRound()
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    let dt = min(deltaTime, 0.05)
    roundTimer += dt

    if !awaitingInput {
      if roundTimer >= 0.8 {
        awaitingInput = true
        roundTimer = 0
        reactionTime = 0
      }
      return
    }

    reactionTime += dt

    if input.posX > 0.5 {
      resolve(with: .right)
    } else if input.posX < -0.5 {
      resolve(with: .left)
    } else if reactionTime > 1.3 {
      failCount += 1
      resultLabel = "TOO SLOW"
      scheduleNextRound()
    }
  }

  func render(context: GameContext) {
    context.rect(x: 0, y: 0, width: GameContext.width, height: GameContext.height, color: .black)
    context.text("REACTION", x: 6, y: 4, color: .white)
    context.text("OK \(successCount)  FAIL \(failCount)", x: 72, y: 4, color: .cyan)

    context.text("TILT \(target.rawValue)", x: 43, y: 35, color: .yellow)
    context.text(resultLabel, x: 50, y: 50, color: .green)
    context.text(String(format: "RT %.2fs", reactionTime), x: 50, y: 63, color: .magenta)
  }

  private func resolve(with direction: TargetDirection) {
    if direction == target {
      successCount += 1
      resultLabel = "SUCCESS"
    } else {
      failCount += 1
      resultLabel = "WRONG"
    }
    scheduleNextRound()
  }

  private func scheduleNextRound() {
    awaitingInput = false
    roundTimer = 0
    reactionTime = 0
    target = Bool.random() ? .left : .right
  }
}
