import Foundation
import VeltoKit

/// Profil wejścia HUD / kalibracji per gra.
struct GameInputProfile {
/// Przechowuje wartosc `lateralGain`.
  var lateralGain: Double?
/// Przechowuje wartosc `rotationWeight`.
  var rotationWeight: Double?
/// Przechowuje wartosc `gyroWeight`.
  var gyroWeight: Double?
/// Przechowuje wartosc `tiltWeight`.
  var tiltWeight: Double?
/// Przechowuje wartosc `lateralDeadzone`.
  var lateralDeadzone: Double?
/// Przechowuje wartosc `lateralSmoothing`.
  var lateralSmoothing: Double?
/// Przechowuje wartosc `movementSpeed`.
  var movementSpeed: Double?
/// Przechowuje wartosc `showsRotation`.
  var showsRotation = true
/// Przechowuje wartosc `showsSteering`.
  var showsSteering = true
/// Przechowuje wartosc `showsTilt`.
  var showsTilt = false
/// Przechowuje wartosc `showsClick`.
  var showsClick = false
/// Przechowuje wartosc `showsMotion`.
  var showsMotion = false
/// Przechowuje wartosc `showsSpeed`.
  var showsSpeed = false
/// Przechowuje wartosc `showsPointer`.
  var showsPointer = false
/// Przechowuje wartosc `motionMode`.
  var motionMode: MotionMode = .paddle

/// Przechowuje wartosc `default`.
  static let `default` = GameInputProfile()

/// Przechowuje wartosc `pong`.
  static let pong = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsRotation: true, showsSteering: true, motionMode: .paddle
  )

/// Przechowuje wartosc `dart`.
  static let dart = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsSteering: true, motionMode: .pointer
  )

/// Przechowuje wartosc `bowling`.
  static let bowling = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsSteering: true, motionMode: .gesture
  )

/// Przechowuje wartosc `quiz`.
  static let quiz = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsRotation: true, showsSteering: true, motionMode: .paddle
  )
}

/// Kontrakt gry — tylko `GameInput`, bez zależności od BLE.
protocol Game: AnyObject {
/// Przechowuje wartosc `name`.
  var name: String { get }
/// Przechowuje wartosc `inputProfile`.
  var inputProfile: GameInputProfile { get }
/// Wykonuje operacje `start`.
  func start(context: GameContext)
/// Wykonuje operacje `update`.
  func update(input: GameInput, deltaTime: TimeInterval)
/// Wykonuje operacje `render`.
  func render(context: GameContext)
}

/// Rozszerza istniejacy typ o dodatkowe zachowanie.
extension Game {
/// Przechowuje wartosc `inputProfile`.
  var inputProfile: GameInputProfile { .default }
}
