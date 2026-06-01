import Foundation

/// Opóźnia przeskakiwanie między opcjami — tilt musi chwilę trzymać nowy slot.
struct TrikiFocusGate {
  private var pendingIndex: Int?
  private var switchRemaining: TimeInterval = 0

  mutating func reset() {
    pendingIndex = nil
    switchRemaining = 0
  }

  /// Zwraca indeks do użycia (może zostać przy `current`, gdy trwa oczekiwanie).
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
