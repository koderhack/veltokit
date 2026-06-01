import Foundation

/// Tryb sterowania (jeden SDK, wiele gier).
public enum MotionMode: String, Sendable, Equatable, CaseIterable {
  case paddle
  case pointer
  case gesture
}

/// Kompatybilność wsteczna z wcześniejszym API.
public typealias PointerInputMode = MotionMode
