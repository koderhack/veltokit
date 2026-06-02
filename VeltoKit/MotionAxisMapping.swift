import Foundation

/// Dostępne źródła osi dla mapowania ruchu.
public enum MotionAxisSource: String, Sendable, CaseIterable {
  case gyroX
  case gyroY
  case gyroZ
  /// Pole 12–13 z ramki Triki — skręt lewo/prawo (najstabilniejsze dla paletki).
  case rotation
}

/// Mapowanie osi żyroskopu na wejście 2D (łatwe do tuningu w debug).
public struct MotionAxisMapping: Equatable, Sendable {
  /// Źródło wejścia dla osi X.
  public var inputX: MotionAxisSource = .rotation
  /// Źródło wejścia dla osi Y.
  public var inputY: MotionAxisSource = .gyroY
  /// Odwraca znak osi X.
  public var invertX: Bool = false
  /// Odwraca znak osi Y.
  public var invertY: Bool = true

  /// Tworzy mapowanie z wartościami domyślnymi.
  public init() {}

  /// Mapuje osie sensorów na osie wejściowe gry.
  ///
  /// - Parameters:
  ///   - gx: Wartość osi gyro X.
  ///   - gy: Wartość osi gyro Y.
  ///   - gz: Wartość osi gyro Z.
  ///   - rotation: Wartość osi rotacji.
  /// - Returns: Krotka `(x, y)` po mapowaniu, inwersji i clamp.
  public func map(
    gx: Double,
    gy: Double,
    gz: Double,
    rotation: Double = 0
  ) -> (x: Double, y: Double) {
    let rawX = pick(inputX, gx: gx, gy: gy, gz: gz, rotation: rotation)
    let rawY = pick(inputY, gx: gx, gy: gy, gz: gz, rotation: rotation)
    let sx = invertX ? -rawX : rawX
    let sy = invertY ? -rawY : rawY
    return (MotionMath.clamp(sx), MotionMath.clamp(sy))
  }

  private func pick(
    _ source: MotionAxisSource,
    gx: Double,
    gy: Double,
    gz: Double,
    rotation: Double
  ) -> Double {
    switch source {
    case .gyroX: return gx
    case .gyroY: return gy
    case .gyroZ: return gz
    case .rotation: return rotation
    }
  }
}
