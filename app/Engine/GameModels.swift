import AudioToolbox
import Foundation

enum GameSFX {
  static func paddleHit() { play(1104) }
  static func wallHit() { play(1057) }
  static func brickHit(level: Int) {
    switch level {
    case 1: play(1110)
    case 2: play(1111)
    default: play(1112)
    }
  }
  static func brickBreak() { play(1113) }
  static func lifeLost() { play(1053) }
  static func win() { play(1025) }

  private static func play(_ id: SystemSoundID) {
    AudioServicesPlaySystemSound(id)
  }
}

struct GameCollider {
  var x: Double
  var y: Double
  var width: Double
  var height: Double

  static func centered(x: Double, y: Double, width: Double, height: Double) -> GameCollider {
    GameCollider(x: x - width / 2, y: y - height / 2, width: width, height: height)
  }

  func overlaps(_ other: GameCollider) -> Bool {
    x < other.x + other.width && x + width > other.x &&
      y < other.y + other.height && y + height > other.y
  }
}
