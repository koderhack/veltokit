import Foundation

/// Focus stabilization primitives for Triki menu navigation.
///
/// The gate delays large focus jumps long enough to suppress jitter while preserving
/// responsive adjacent-item movement.

/// Stabilizes focus transitions between Triki menu slots.
///
/// Use this gate when raw slot selection is jittery and should switch only after a short dwell.
struct TrikiFocusGate {
  private var pendingIndex: Int?
  private var switchRemaining: TimeInterval = 0

  /// Clears pending transition state.
  mutating func reset() {
    pendingIndex = nil
    switchRemaining = 0
  }

  /// Resolves the effective focused index for the current frame.
  ///
  /// - Parameters:
  ///   - rawIndex: Slot suggested by current motion sample.
  ///   - current: Currently focused slot.
  ///   - deltaTime: Elapsed frame time in seconds.
  /// - Returns: Active slot to render and use for activation. Can remain on `current` while dwell
  ///   timing is still in progress.
  mutating func resolve(rawIndex: Int?, current: Int?, deltaTime: TimeInterval) -> Int? {
    guard let rawIndex else {
      reset()
      return nil
    }
    guard let current, rawIndex != current else {
      pendingIndex = nil
      switchRemaining = 0
      return rawIndex
    }

    let dwell = abs(rawIndex - current) == 1
      ? TrikiUIConfig.focusSwitchDurationAdjacent
      : TrikiUIConfig.focusSwitchDuration

    if pendingIndex != rawIndex {
      pendingIndex = rawIndex
      switchRemaining = dwell
      if dwell <= 0 {
        pendingIndex = nil
        return rawIndex
      }
      return current
    }

    switchRemaining -= deltaTime
    if switchRemaining <= 0 {
      pendingIndex = nil
      return rawIndex
    }
    return current
  }
}
