import AudioToolbox
import Foundation
import TrikiMotionKit

struct GameInputProfile {
  var lateralGain: Double?
  var rotationWeight: Double?
  var gyroWeight: Double?
  var tiltWeight: Double?
  var lateralDeadzone: Double?
  var lateralSmoothing: Double?
  var movementSpeed: Double?
  var showsRotation = true
  var showsSteering = true
  var showsTilt = false
  var showsClick = false
  var showsMotion = false
  var showsSpeed = false
  var showsPointer = false
  var motionMode: MotionMode = .paddle

  static let `default` = GameInputProfile()

  static let road = GameInputProfile(
    lateralGain: 3.8,
    rotationWeight: 0,
    gyroWeight: 1,
    tiltWeight: 0,
    lateralDeadzone: 0.03,
    lateralSmoothing: 0.3,
    movementSpeed: 260,
    showsRotation: true,
    showsSteering: true,
    showsTilt: false,
    showsClick: false,
    showsMotion: false,
    showsSpeed: true,
    motionMode: .paddle
  )

  static let snake = GameInputProfile(
    lateralGain: 2.0,
    rotationWeight: 0,
    gyroWeight: 0,
    tiltWeight: 0,
    lateralDeadzone: 0.03,
    lateralSmoothing: 0.3,
    movementSpeed: 140,
    showsRotation: true,
    showsSteering: false,
    showsTilt: false,
    showsClick: false,
    showsMotion: false,
    showsSpeed: false
  )

  static let breakout = GameInputProfile(
    lateralGain: 2.5,
    rotationWeight: 0,
    gyroWeight: 0,
    tiltWeight: 0,
    lateralDeadzone: 0.04,
    lateralSmoothing: 0.2,
    movementSpeed: 220,
    showsRotation: true,
    showsSteering: true,
    showsTilt: false,
    showsClick: false,
    showsMotion: false,
    showsSpeed: false,
    motionMode: .paddle
  )

  static let pong = GameInputProfile(
    lateralGain: 2.5,
    rotationWeight: 0,
    gyroWeight: 1,
    tiltWeight: 0,
    lateralDeadzone: 0.03,
    lateralSmoothing: 0.2,
    movementSpeed: 220,
    showsRotation: true,
    showsSteering: true,
    showsTilt: false,
    showsClick: false,
    showsMotion: false,
    showsSpeed: false,
    motionMode: .paddle
  )

  static let dart = GameInputProfile(
    lateralGain: 1.5,
    rotationWeight: 0,
    gyroWeight: 1,
    tiltWeight: 0,
    lateralDeadzone: 0.03,
    lateralSmoothing: 0.2,
    movementSpeed: 200,
    showsRotation: false,
    showsSteering: false,
    showsTilt: false,
    showsClick: true,
    showsMotion: false,
    showsSpeed: false,
    showsPointer: true,
    motionMode: .gesture
  )

  static let catchGame = GameInputProfile(
    lateralGain: 2.0,
    rotationWeight: 0,
    gyroWeight: 0,
    tiltWeight: 0,
    lateralDeadzone: 0.04,
    lateralSmoothing: 0.2,
    movementSpeed: 220,
    showsRotation: true,
    showsSteering: true,
    showsTilt: false,
    showsClick: false,
    showsMotion: false,
    showsSpeed: false,
    motionMode: .paddle
  )

  static let reactionTilt = GameInputProfile(
    lateralGain: 1.0,
    rotationWeight: 0,
    gyroWeight: 0,
    tiltWeight: 0,
    lateralDeadzone: 0.05,
    lateralSmoothing: 0.15,
    movementSpeed: 120,
    showsRotation: true,
    showsSteering: false,
    showsTilt: false,
    showsClick: false,
    showsMotion: false,
    showsSpeed: false,
    motionMode: .paddle
  )

  static let reflexShot = GameInputProfile(
    lateralGain: 1.5,
    rotationWeight: 0,
    gyroWeight: 0,
    tiltWeight: 0,
    lateralDeadzone: 0.04,
    lateralSmoothing: 0.2,
    movementSpeed: 200,
    showsRotation: false,
    showsSteering: false,
    showsTilt: false,
    showsClick: true,
    showsMotion: false,
    showsSpeed: false,
    showsPointer: true,
    motionMode: .pointer
  )
}

protocol Game: AnyObject {
  var name: String { get }
  var inputProfile: GameInputProfile { get }
  func start(context: GameContext)
  func update(input: GameInput, deltaTime: TimeInterval)
  func render(context: GameContext)
}

extension Game {
  var inputProfile: GameInputProfile { .default }
}

enum PixelColor: UInt8 {
  case black
  case darkGray
  case road
  case grass
  case white
  case cyan
  case magenta
  case green
  case yellow
  case red
}

/// Proste efekty dźwiękowe (bez plików audio).
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

enum DrawCommand {
  case rect(x: Int, y: Int, width: Int, height: Int, color: PixelColor)
  case text(value: String, x: Int, y: Int, color: PixelColor)
}

/// Prosty collider AABB do gier 2D (axis-aligned bounding box).
struct GameCollider {
  var x: Double
  var y: Double
  var width: Double
  var height: Double

  static func centered(x: Double, y: Double, width: Double, height: Double) -> GameCollider {
    GameCollider(
      x: x - width / 2,
      y: y - height / 2,
      width: width,
      height: height
    )
  }

  func overlaps(_ other: GameCollider) -> Bool {
    x < other.x + other.width &&
    x + width > other.x &&
    y < other.y + other.height &&
    y + height > other.y
  }
}

final class GameContext {
  static let width = 160
  static let height = 90

  private(set) var commands: [DrawCommand] = []

  /// Kopia do `@Published` — wymusza odświeżenie widoku co klatkę.
  var commandSnapshot: [DrawCommand] { Array(commands) }

  func clear() {
    commands.removeAll(keepingCapacity: true)
  }

  func rect(x: Int, y: Int, width: Int, height: Int, color: PixelColor = .white) {
    commands.append(.rect(x: x, y: y, width: width, height: height, color: color))
  }

  func text(_ string: String, x: Int, y: Int, color: PixelColor = .white) {
    commands.append(.text(value: string, x: x, y: y, color: color))
  }
}
