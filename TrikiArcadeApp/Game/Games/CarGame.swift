import Foundation
import TrikiMotionKit

// Najprostszy możliwy przykład gry z autem.
// Cel: pokazać, że `input.rotation` działa i jest czytelne dla devów.
final class CarGame: Game {
  let name = "Car Game"
  let inputProfile: GameInputProfile = .road

  private static let carHalfWidth = 17.0

  private var carX = Double(GameContext.width) / 2
  private var roadScroll = 0.0

  func start(context: GameContext) {
    carX = Double(GameContext.width) / 2
    roadScroll = 0
  }
  func update(input: GameInput, deltaTime: TimeInterval) {
    let dt = min(deltaTime, 0.05)
    let minX = Self.carHalfWidth
    let maxX = Double(GameContext.width) - Self.carHalfWidth
    let targetX = MotionControls.screenX(
      posX: input.posX,
      width: Double(GameContext.width)
    )
    carX = min(maxX, max(minX, targetX))
  }

  func render(context: GameContext) {
    let w = GameContext.width
    let h = GameContext.height
    let carXi = Int(carX.rounded())
    let horizonY = 24

    // tło
    context.rect(x: 0, y: 0, width: w, height: horizonY, color: .darkGray)

    // droga z prostą perspektywą
    for y in horizonY..<h {
      let t = Double(y - horizonY) / Double(h - horizonY)
      let halfRoad = 8 + Int(t * 40)
      let center = w / 2
      context.rect(x: 0, y: y, width: center - halfRoad, height: 1, color: .grass)
      context.rect(x: center - halfRoad, y: y, width: halfRoad * 2, height: 1, color: .road)
      context.rect(x: center + halfRoad, y: y, width: w - center - halfRoad, height: 1, color: .grass)
      context.rect(x: center - halfRoad, y: y, width: 1, height: 1, color: .white)
      context.rect(x: center + halfRoad - 1, y: y, width: 1, height: 1, color: .white)

      // środkowe kreski
      let stripe = Int(roadScroll + Double(y) * 0.6) % 16
      if stripe < 6 {
        let markW = max(1, halfRoad / 6)
        context.rect(x: center - markW / 2, y: y, width: markW, height: 1, color: .yellow)
      }
    }

    // auto (proste, ale czytelniejsze)
    let y = h - 12
    let half = Int(Self.carHalfWidth)
    context.rect(x: carXi - half, y: y - 6, width: half * 2, height: 15, color: .black)
    context.rect(x: carXi - 16, y: y, width: 32, height: 8, color: .cyan)
    context.rect(x: carXi - 11, y: y - 5, width: 22, height: 6, color: .darkGray)
    context.rect(x: carXi - 9, y: y - 3, width: 18, height: 3, color: .white)
    context.rect(x: carXi - 14, y: y + 7, width: 5, height: 2, color: .yellow)
    context.rect(x: carXi + 9, y: y + 7, width: 5, height: 2, color: .yellow)
  }
}
