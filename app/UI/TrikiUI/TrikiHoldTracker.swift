import Foundation

/// Przytrzymanie na jednej opcji — pasek 0…1, impuls przy 1.
struct TrikiHoldTracker {
  private(set) var progress: Double = 0
  private(set) var didComplete = false

  mutating func reset() {
    progress = 0
    didComplete = false
  }

  @discardableResult
  mutating func advance(deltaTime: TimeInterval, duration: TimeInterval = 2.25) -> Bool {
    didComplete = false
    guard duration > 0 else { return false }
    progress = min(1, progress + deltaTime / duration)
    if progress >= 1 {
      didComplete = true
      progress = 0
      return true
    }
    return false
  }

  mutating func decay(deltaTime: TimeInterval, rate: Double = 2.5) {
    didComplete = false
    progress = max(0, progress - deltaTime * rate)
  }
}
