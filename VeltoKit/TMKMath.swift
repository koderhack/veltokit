import Foundation

/// Zestaw funkcji matematycznych używanych w potoku ruchu.
public enum MotionMath {
  /// Ogranicza wartość do zadanego przedziału.
  public static func clamp(_ value: Double, min lower: Double = -1, max upper: Double = 1) -> Double {
    Swift.min(upper, Swift.max(lower, value))
  }

  /// Ustawia zero dla wartości wewnątrz deadzone.
  public static func threshold(_ value: Double, deadzone: Double) -> Double {
    abs(value) < deadzone ? 0 : value
  }

  /// Deadzone bez „dziury” — małe ruchy są słabsze, ale nadal działają.
  public static func softDeadzone(_ value: Double, deadzone: Double) -> Double {
    let magnitude = abs(value)
    guard magnitude > deadzone else { return 0 }
    let sign = value >= 0 ? 1.0 : -1.0
    let scaled = (magnitude - deadzone) / max(1.0 - deadzone, 0.001)
    return sign * min(1.0, scaled)
  }

  /// Większa czułość przy małych kątach (wykładnik < 1).
  public static func responseCurve(_ value: Double, exponent: Double = 0.72) -> Double {
    let sign = value >= 0 ? 1.0 : -1.0
    return sign * pow(abs(value), exponent)
  }

  /// Interpoluje liniowo między bieżącą i docelową wartością.
  public static func smooth(current: Double, target: Double, alpha: Double) -> Double {
    current + (target - current) * alpha
  }

  /// Skaluje sygnał o zadany współczynnik.
  public static func amplify(_ value: Double, factor: Double) -> Double {
    value * factor
  }

  /// Ogranicza amplitudę sygnału do `±magnitude`.
  public static func limit(_ value: Double, max magnitude: Double) -> Double {
    clamp(value, min: -magnitude, max: magnitude)
  }
}
