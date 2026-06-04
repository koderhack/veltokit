import Foundation
import VeltoKit

/// Debounced rising-edge gate for the physical Triki BLE button.
///
/// Use for quiz answer confirm and menu activation when motion velocity must not
/// trigger `primaryAction`.
struct TrikiButtonConfirmGate {
  static let postConfirmCooldown: TimeInterval = 0.65

  private var lastRaw = false
  private var cooldown: TimeInterval = 0

  mutating func reset() {
    lastRaw = false
    cooldown = 0
  }

  /// Returns `true` only on the first frame of a button impulse after cooldown.
  mutating func consume(input: GameInput, deltaTime: TimeInterval) -> Bool {
    cooldown = max(0, cooldown - deltaTime)
    let raw = input.primaryAction
    let edge = raw && !lastRaw
    lastRaw = raw
    guard edge, cooldown <= 0 else { return false }
    cooldown = Self.postConfirmCooldown
    return true
  }
}
