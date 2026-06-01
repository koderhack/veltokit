import Foundation
import VeltoKit

/// Profil wejścia HUD / kalibracji per gra.
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

  static let pong = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsRotation: true, showsSteering: true, motionMode: .paddle
  )

  static let dart = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsSteering: true, motionMode: .pointer
  )

  static let bowling = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsSteering: true, motionMode: .gesture
  )

  static let quiz = GameInputProfile(
    lateralGain: 2.5, rotationWeight: 0, gyroWeight: 1, tiltWeight: 0,
    lateralDeadzone: 0.03, lateralSmoothing: 0.2, movementSpeed: 220,
    showsRotation: true, showsSteering: true, motionMode: .paddle
  )
}

/// Kontrakt gry — tylko `GameInput`, bez zależności od BLE.
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
