import Foundation

/// Tryb sterowania (jeden SDK, wiele gier).
public enum MotionMode: String, Sendable, Equatable, CaseIterable {
  /// Sterowanie paletką na jednej osi.
  case paddle
  /// Sterowanie wskaźnikiem 2D.
  case pointer
  /// Sterowanie wskaźnikiem z wykrywaniem rzutu.
  case gesture
}

/// Kompatybilność wsteczna z wcześniejszym API.
public typealias PointerInputMode = MotionMode
