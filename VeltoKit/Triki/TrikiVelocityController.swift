import Foundation

/// Limity Δpos / velocity per tryb BLE — deadzone → clamp → scale.
public struct TrikiVelocityLimits: Sendable, Equatable {
  /// Poniżej tej wartości |Δ| jest ignorowane (jitter).
  public var deadzone: Double
  /// Maks. |Δ| przed skalowaniem (koniec „latania”).
  public var maxMagnitude: Double
  /// Mnożnik siły po clampie (0…1 typowo niższy w FAST).
  public var sensitivity: Double

  public init(deadzone: Double, maxMagnitude: Double, sensitivity: Double) {
    self.deadzone = deadzone
    self.maxMagnitude = maxMagnitude
    self.sensitivity = sensitivity
  }

  public static func preset(for mode: TrikiBLEMode) -> TrikiVelocityLimits {
    switch mode.inputStrategy {
    case .velocity:
      return TrikiVelocityLimits(deadzone: 0.004, maxMagnitude: 0.012, sensitivity: 0.22)
    case .hybrid:
      return TrikiVelocityLimits(deadzone: 0.0018, maxMagnitude: 0.028, sensitivity: 0.42)
    case .threshold:
      return TrikiVelocityLimits(deadzone: 0.005, maxMagnitude: 0.045, sensitivity: 0.62)
    }
  }
}

/// Okiełznianie szybkiego strumienia — deadzone, clamp, scale (plug & play).
public enum TrikiVelocityController {
  /// Stosuje deadzone → clamp → sensitivity do pojedynczej osi Δ.
  public static func shape(_ raw: Double, limits: TrikiVelocityLimits) -> Double {
    guard abs(raw) >= limits.deadzone else { return 0 }
    let clamped = min(limits.maxMagnitude, max(-limits.maxMagnitude, raw))
    return clamped * limits.sensitivity
  }

  /// Jak `shape`, z presetem dla `bleMode`.
  public static func shape(_ raw: Double, mode: TrikiBLEMode) -> Double {
    shape(raw, limits: .preset(for: mode))
  }

  /// Δpos z `GameInput` (lub fallback) po okiełznaniu.
  public static func shapedFrameDeltaX(
    input: GameInput,
    fallbackRaw: Double,
    limits: TrikiVelocityLimits? = nil
  ) -> Double {
    let lim = limits ?? .preset(for: input.bleMode)
    let raw = input.frameDeltaX != 0 ? input.frameDeltaX : fallbackRaw
    return shape(raw, limits: lim)
  }

  /// Δpos Y po okiełznaniu.
  public static func shapedFrameDeltaY(
    input: GameInput,
    fallbackRaw: Double = 0,
    limits: TrikiVelocityLimits? = nil
  ) -> Double {
    let lim = limits ?? .preset(for: input.bleMode)
    let raw = input.frameDeltaY != 0 ? input.frameDeltaY : fallbackRaw
    return shape(raw, limits: lim)
  }

  /// Prędkość Triki po okiełznaniu (do impulsów / nudge).
  public static func shapedTrikiVelocity(
    _ velocity: Double,
    mode: TrikiBLEMode
  ) -> Double {
    let lim = TrikiVelocityLimits(
      deadzone: 1.2,
      maxMagnitude: mode.inputStrategy == .velocity ? 4 : 6,
      sensitivity: mode.inputStrategy == .velocity ? 0.25 : 0.45
    )
    return shape(velocity, limits: lim)
  }
}
