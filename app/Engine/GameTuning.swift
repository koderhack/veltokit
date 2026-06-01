import Foundation
import Combine
import VeltoKit

@MainActor
final class GameTuning: ObservableObject {
  @Published var lateralGain: Double { didSet { save() } }
  @Published var rotationWeight: Double { didSet { save() } }
  @Published var gyroWeight: Double { didSet { save() } }
  @Published var tiltWeight: Double { didSet { save() } }
  @Published var lateralDeadzone: Double { didSet { save() } }
  @Published var lateralSmoothing: Double { didSet { save() } }
  @Published var movementSpeed: Double { didSet { save() } }

  init() {
    let d = UserDefaults.standard
    lateralGain = d.object(forKey: Keys.lateralGain) as? Double ?? 3.5
    rotationWeight = d.object(forKey: Keys.rotationWeight) as? Double ?? 0
    gyroWeight = d.object(forKey: Keys.gyroWeight) as? Double ?? 1
    tiltWeight = d.object(forKey: Keys.tiltWeight) as? Double ?? 0
    lateralDeadzone = d.object(forKey: Keys.lateralDeadzone) as? Double ?? 0.01
    lateralSmoothing = d.object(forKey: Keys.lateralSmoothing) as? Double ?? 10
    movementSpeed = d.object(forKey: Keys.movementSpeed) as? Double ?? 260
  }

  func resetToDefaults() {
    lateralGain = 3.5
    rotationWeight = 0
    gyroWeight = 1
    tiltWeight = 0
    lateralDeadzone = 0.03
    lateralSmoothing = 0.3
    movementSpeed = 260
  }

  private enum Keys {
    static let lateralGain = "gameTuning.lateralGain"
    static let rotationWeight = "gameTuning.rotationWeight"
    static let gyroWeight = "gameTuning.gyroWeight"
    static let tiltWeight = "gameTuning.tiltWeight"
    static let lateralDeadzone = "gameTuning.lateralDeadzone"
    static let lateralSmoothing = "gameTuning.lateralSmoothing"
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
