import AudioToolbox
import Foundation

/// Reprezentuje typ `GameSFX`.
enum GameSFX {
/// Wykonuje operacje `paddleHit`.
  static func paddleHit() { play(1104) }
/// Wykonuje operacje `wallHit`.
  static func wallHit() { play(1057) }
/// Wykonuje operacje `brickHit`.
  static func brickHit(level: Int) {
    switch level {
    case 1: play(1110)
    case 2: play(1111)
    default: play(1112)
    }
  }
/// Wykonuje operacje `brickBreak`.
  static func brickBreak() { play(1113) }
/// Wykonuje operacje `lifeLost`.
  static func lifeLost() { play(1053) }
/// Wykonuje operacje `win`.
  static func win() { play(1025) }

  private static func play(_ id: SystemSoundID) {
    AudioServicesPlaySystemSound(id)
  }
}

/// Reprezentuje typ `GameCollider`.
struct GameCollider {
/// Przechowuje wartosc `x`.
  var x: Double
/// Przechowuje wartosc `y`.
  var y: Double
/// Przechowuje wartosc `width`.
  var width: Double
/// Przechowuje wartosc `height`.
  var height: Double

/// Wykonuje operacje `centered`.
  static func centered(x: Double, y: Double, width: Double, height: Double) -> GameCollider {
    GameCollider(x: x - width / 2, y: y - height / 2, width: width, height: height)
  }

/// Wykonuje operacje `overlaps`.
  func overlaps(_ other: GameCollider) -> Bool {
    x < other.x + other.width && x + width > other.x &&
      y < other.y + other.height && y + height > other.y
  }
}
