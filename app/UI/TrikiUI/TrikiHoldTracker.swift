import Foundation

/// Hold-progress state machine used by Triki confirmation flows.
///
/// This helper encapsulates hold accumulation and decay so views can render progress bars
/// and trigger activation without duplicating timing logic.

/// Tracks hold-to-confirm progress for the currently focused Triki menu item.
///
/// Use this helper in UI navigation where activation should require sustained focus rather than
/// immediate trigger.
struct TrikiHoldTracker {
  /// Current hold progress in the `0...1` range.
  private(set) var progress: Double = 0
  /// Becomes `true` for one tick when hold completion threshold is reached.
  private(set) var didComplete = false

  /// Resets hold state to initial values.
  mutating func reset() {
    progress = 0
    didComplete = false
  }

  /// Advances hold progress and reports completion.
  ///
  /// - Parameters:
  ///   - deltaTime: Elapsed frame time in seconds.
  ///   - duration: Required hold duration in seconds.
  /// - Returns: `true` when a full hold gesture is completed during this tick.
  /// - Side Effects: Resets `progress` to `0` after completion to support repeated activations.
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

  /// Gradually decreases hold progress when focus is unstable.
  ///
  /// - Parameters:
  ///   - deltaTime: Elapsed frame time in seconds.
  ///   - rate: Decay speed per second.
  mutating func decay(deltaTime: TimeInterval, rate: Double = 2.5) {
    didComplete = false
    progress = max(0, progress - deltaTime * rate)
  }
}
