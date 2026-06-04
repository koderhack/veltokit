import Foundation
import Combine
import VeltoKit

@MainActor
/// Reprezentuje typ `GameTuning`.
final class GameTuning: ObservableObject {
  @Published var lateralGain: Double { didSet { save() } }
  @Published var rotationWeight: Double { didSet { save() } }
  @Published var gyroWeight: Double { didSet { save() } }
  @Published var tiltWeight: Double { didSet { save() } }
  @Published var lateralDeadzone: Double { didSet { save() } }
  @Published var lateralSmoothing: Double { didSet { save() } }
  @Published var movementSpeed: Double { didSet { save() } }

/// Inicjalizuje nowa instancje.
  init() {
    let d = UserDefaults.standard
    lateralGain = d.object(forKey: Keys.lateralGain) as? Double ?? 3.5
    rotationWeight = d.object(forKey: Keys.rotationWeight) as? Double ?? 0
    gyroWeight = d.object(forKey: Keys.gyroWeight) as? Double ?? 1
    tiltWeight = d.object(forKey: Keys.tiltWeight) as? Double ?? 0
    lateralDeadzone = d.object(forKey: Keys.lateralDeadzone) as? Double ?? 0.01
    lateralSmoothing = d.object(forKey: Keys.lateralSmoothing) as? Double ?? 0
    movementSpeed = d.object(forKey: Keys.movementSpeed) as? Double ?? 260
  }

/// Wykonuje operacje `resetToDefaults`.
  func resetToDefaults() {
    lateralGain = 3.5
    rotationWeight = 0
    gyroWeight = 1
    tiltWeight = 0
    lateralDeadzone = 0.03
    lateralSmoothing = 0
    movementSpeed = 260
  }

  private enum Keys {
/// Przechowuje wartosc `lateralGain`.
    static let lateralGain = "gameTuning.lateralGain"
/// Przechowuje wartosc `rotationWeight`.
    static let rotationWeight = "gameTuning.rotationWeight"
/// Przechowuje wartosc `gyroWeight`.
    static let gyroWeight = "gameTuning.gyroWeight"
/// Przechowuje wartosc `tiltWeight`.
    static let tiltWeight = "gameTuning.tiltWeight"
/// Przechowuje wartosc `lateralDeadzone`.
    static let lateralDeadzone = "gameTuning.lateralDeadzone"
/// Przechowuje wartosc `lateralSmoothing`.
    static let lateralSmoothing = "gameTuning.lateralSmoothing"
/// Przechowuje wartosc `movementSpeed`.
    static let movementSpeed = "gameTuning.movementSpeed"
  }

  private func save() {
    let d = UserDefaults.standard
    d.set(lateralGain, forKey: Keys.lateralGain)
    d.set(rotationWeight, forKey: Keys.rotationWeight)
    d.set(gyroWeight, forKey: Keys.gyroWeight)
    d.set(tiltWeight, forKey: Keys.tiltWeight)
    d.set(lateralDeadzone, forKey: Keys.lateralDeadzone)
    d.set(lateralSmoothing, forKey: Keys.lateralSmoothing)
    d.set(movementSpeed, forKey: Keys.movementSpeed)
  }
}
