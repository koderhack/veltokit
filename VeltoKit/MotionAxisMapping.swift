import Foundation

public enum MotionAxisSource: String, Sendable, CaseIterable {
  case gyroX
  case gyroY
  case gyroZ
  /// Pole 12–13 z ramki Triki — skręt lewo/prawo (najstabilniejsze dla paletki).
  case rotation
}

/// Mapowanie osi żyroskopu na wejście 2D (łatwe do tuningu w debug).
public struct MotionAxisMapping: Equatable, Sendable {
  public var inputX: MotionAxisSource = .rotation
  public var inputY: MotionAxisSource = .gyroY
  public var invertX: Bool = false
  public var invertY: Bool = true

  public init() {}

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
