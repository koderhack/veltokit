import Foundation
import TrikiMotionKit

final class ReflexShotGame: Game {
  let name = "Reflex Shot"
  let inputProfile: GameInputProfile = .reflexShot

  private var aimX = Double(GameContext.width) / 2
  private var aimY = Double(GameContext.height) / 2
  private var targets: [(x: Double, y: Double, alive: Bool)] = []
  private var score = 0
  private var misses = 0
  private var spawnTimer = 0.0
  private var hitFlash = 0.0

  func start(context: GameContext) {
    aimX = Double(GameContext.width) / 2
    aimY = Double(GameContext.height) / 2
    score = 0
    misses = 0
    spawnTimer = 0
    hitFlash = 0
    targets.removeAll(keepingCapacity: true)
    spawnTarget()
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    let dt = min(deltaTime, 0.05)
    let screen = MotionControls.pointerScreenPosition(
      input: input,
      width: Double(GameContext.width),
      height: Double(GameContext.height)
    )
    aimX = screen.x
    aimY = screen.y

    spawnTimer += dt
    if spawnTimer >= 1.4, targets.filter(\.alive).count < 4 {
      spawnTarget()
      spawnTimer = 0
    }

    if hitFlash > 0 {
      hitFlash -= dt
    }

    if input.shotTriggered {
      handleShot()
    }
  }

  func render(context: GameContext) {
    let w = GameContext.width
    let h = GameContext.height
    context.rect(x: 0, y: 0, width: w, height: h, color: .black)
    context.text("REFLEX SHOT", x: 6, y: 4, color: .white)
    context.text("S \(score)  M \(misses)", x: 88, y: 4, color: .cyan)
    context.text("FLICK UP = SHOOT", x: 6, y: 78, color: .yellow)

    for target in targets where target.alive {
      context.rect(
        x: Int(target.x.rounded()) - 3,
        y: Int(target.y.rounded()) - 3,
        width: 6,
        height: 6,
        color: .magenta
      )
    }

    let crossColor: PixelColor = hitFlash > 0 ? .yellow : .green
    context.rect(x: Int(aimX.rounded()) - 2, y: Int(aimY.rounded()), width: 5, height: 1, color: crossColor)
    context.rect(x: Int(aimX.rounded()), y: Int(aimY.rounded()) - 2, width: 1, height: 5, color: crossColor)
  }

  private func spawnTarget() {
    let x = Double.random(in: 16...(Double(GameContext.width) - 16))
    let y = Double.random(in: 14...(Double(GameContext.height) - 20))
    targets.append((x: x, y: y, alive: true))
  }

  private func handleShot() {
    let hitRadius = 8.0
    var hit = false
    for index in targets.indices where targets[index].alive {
      let t = targets[index]
      let dx = aimX - t.x
      let dy = aimY - t.y
      if dx * dx + dy * dy <= hitRadius * hitRadius {
        targets[index].alive = false
        score += 1
        hit = true
        hitFlash = 0.15
        break
      }
    }
    if !hit {
      misses += 1
    }
    targets.removeAll { !$0.alive }
    if targets.filter(\.alive).isEmpty {
      spawnTarget()
    }
  }
}
