import Foundation
import TrikiMotionKit

/// Dart — tryb `.pointer` + strzał z gestu (relY).
final class DartGame: Game {
  let name = "Dart"
  let inputProfile: GameInputProfile = .dart

  private var cursorX = Double(GameContext.width / 2)
  private var cursorY = Double(GameContext.height / 2)
  private var totalScore = 0
  private var lastHitLabel = "AIM"
  private var hitFlash = 0.0
  private var shots = 0

  private let boardCX = Double(GameContext.width / 2)
  private let boardCY = 36.0
  private let boardRadius = 28.0

  func start(context: GameContext) {
    cursorX = boardCX
    cursorY = boardCY + boardRadius + 8
    totalScore = 0
    shots = 0
    lastHitLabel = "AIM"
    hitFlash = 0
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    let dt = min(deltaTime, 0.05)
    let screen = MotionControls.pointerScreenPosition(
      input: input,
      width: Double(GameContext.width),
      height: Double(GameContext.height)
    )
    cursorX = screen.x
    cursorY = screen.y

    if hitFlash > 0 {
      hitFlash -= dt
    }

    if input.shotTriggered || input.primaryAction {
      registerShot()
    }
  }

  func render(context: GameContext) {
    let w = GameContext.width
    let h = GameContext.height
    context.rect(x: 0, y: 0, width: w, height: h, color: .black)
    context.text("DART", x: 6, y: 4, color: .white)
    context.text("PTS \(totalScore)  #\(shots)", x: 72, y: 4, color: .cyan)
    context.text("FLICK UP = THROW", x: 6, y: 78, color: .yellow)

    drawTarget(context: context)
    drawCursor(context: context)
    context.text(lastHitLabel, x: 52, y: 58, color: hitFlash > 0 ? .yellow : .green)
  }

  private func drawTarget(context: GameContext) {
    let cx = Int(boardCX.rounded())
    let cy = Int(boardCY.rounded())
    context.rect(x: cx - 2, y: cy - 2, width: 5, height: 5, color: .red)
    context.rect(x: cx - 10, y: cy - 10, width: 20, height: 20, color: .magenta)
    context.rect(x: cx - 18, y: cy - 18, width: 36, height: 36, color: .darkGray)
  }

  private func drawCursor(context: GameContext) {
    let color: PixelColor = hitFlash > 0 ? .yellow : .cyan
    let xi = Int(cursorX.rounded())
    let yi = Int(cursorY.rounded())
    context.rect(x: xi - 2, y: yi, width: 5, height: 1, color: color)
    context.rect(x: xi, y: yi - 2, width: 1, height: 5, color: color)
  }

  private func registerShot() {
    shots += 1
    let dx = (cursorX - boardCX) / boardRadius
    let dy = (cursorY - boardCY) / boardRadius
    let distance = sqrt(dx * dx + dy * dy)

    let points: Int
    if distance < 0.1 {
      points = 10
      lastHitLabel = "BULL 10"
    } else if distance < 0.3 {
      points = 5
      lastHitLabel = "RING 5"
    } else if distance < 0.55 {
      points = 2
      lastHitLabel = "HIT 2"
    } else {
      points = 0
      lastHitLabel = "MISS"
    }
    totalScore += points
    hitFlash = 0.2
  }
}
