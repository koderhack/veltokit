import Foundation

/// Źródło BLE dla silnika (blok 0 = tilt, blok 1 = żyro).
public enum MotionSensorInput: String, Sendable, Equatable {
  case tilt
  case gyro
}

public struct MotionConfig: Equatable, Sendable {
  public var mode: MotionMode = .paddle
  public var axisMapping = MotionAxisMapping()
  public var sensorInput: MotionSensorInput = .gyro

  // Core pipeline
  public var inputSmoothing: Double = 0.15
  public var deadzone: Double = 0.01
  public var referenceBlend: Double = 0.005
  public var referenceRetain: Double = 0.995
  /// Wyłączone w `.paddle` — inaczej ref „goni” tilt i relX pojawia się z opóźnieniem.
  public var referenceDriftEnabled: Bool = true

  // Paddle — delta×gain → smooth 0.8/0.2 → posX (absolutna, bez +=)
  public var paddleInputGain: Double = 0.3
  /// Po gain: |input| poniżej progu → 0 (filtr mikro-szumu IMU, typ. 0.3–0.7).
  public var paddleMicroDeadzone: Double = 0.5
  /// Auto-kalibracja: |raw−offset| poniżej progu = „spokój” (surowe jednostki BLE).
  public var paddleStillThreshold: Double = 3
  public var paddleAutoCalibRetain: Double = 0.98
  public var paddleAutoCalibBlend: Double = 0.02
  public var paddleAutoCalibEnabled: Bool = true
  /// Auto-offset tylko gdy |smoothX| poniżej (unika „walki” ze sterowaniem).
  public var paddleAutoCalibMaxSteer: Double = 0.06
  /// smooth = smooth * retain + input * blend (ruch — szybciej).
  public var paddleSmoothRetain: Double = 0.72
  public var paddleSmoothBlend: Double = 0.28
  /// Powrót do środka gdy brak inputu (wolniej = mniej skoków).
  public var paddleSmoothRetainIdle: Double = 0.86
  /// Bezpiecznik runaway — clamp smooth (nie reset do 0).
  public var paddleSmoothMax: Double = 2
  /// delta / divisor przed gain (surowe int16 z BLE).
  public var paddleRawDivisor: Double = 100
  /// Gdy |raw−offset| < deadband → powrót smooth do 0.
  public var paddleRawDeadband: Double = 8
  public var paddleReturnDecay: Double = 0.88
  public var paddleRawDeadbandRelease: Double = 3
  /// Filtr surowego BLE przed deltą (0.35 ≈ tłumi ±1–2 bez dużego lagu).
  public var paddleRawSmoothing: Double = 0.35
  public var paddleIntegrateRate: Double = 0
  /// Mnożnik smoothX → offset od środka (UI / gra).
  public var paddleScreenScale: Double = 66
  // Legacy pola zostawione dla zgodności UI DEV (nieużywane w nowym modelu).
  public var paddlePositionGain: Double = 2.5
  public var paddlePositionFollow: Double = 0.2
  public var paddleSpikeThreshold: Double = 500
  public var paddleZeroSnap: Double = 0.02
  // Legacy pola zostawione dla zgodności UI DEV (nieużywane w nowym modelu).
  public var paddleGyroAssist: Double = 0
  public var paddleVelocityRetain: Double = 0
  public var paddleVelocityBlend: Double = 0
  public var paddleDamping: Double = 0.98
  public var paddleBiasRetain: Double = 0.995
  public var paddleBiasBlend: Double = 0.005
  public var paddleSnapThreshold: Double = 0
  public var paddleSnapBoost: Double = 0
  public var paddleIdleVelocityDecay: Double = 0
  public var paddleVelocityStop: Double = 0
  public var paddleBiasLearnMax: Double = 0
  public var paddleMaxVelocity: Double = 0
  public var paddleOutputSmoothing: Double = 0
  public var paddleRestHysteresis: Double = 0
  public var paddleActiveThreshold: Double = 0

  // Core rotation (akumulacja)
  public var pointerSensitivity: Double = 0.03
  public var pointerRotDamping: Double = 0.98
  public var pointerOutputSmoothing: Double = 0.15

  // Gesture / shoot
  public var gestureThreshold: Double = 0.35
  public var gestureCooldown: TimeInterval = 0.4
  public var gestureMinRelY: Double = 0.08

  public init() {}

  public static let `default` = MotionConfig.preset(for: .paddle)

  /// Gotowe parametry dla trybu — bez ręcznego tuningu w UI.
  public static func preset(for mode: MotionMode) -> MotionConfig {
    var cfg = MotionConfig()
    cfg.mode = mode
    cfg.inputSmoothing = 1.0
    cfg.referenceBlend = 0.005
    cfg.referenceRetain = 0.995

    switch mode {
    case .paddle:
      cfg.sensorInput = .gyro
      cfg.axisMapping.inputX = .gyroY
      cfg.axisMapping.inputY = .gyroX
      cfg.axisMapping.invertX = false
      cfg.axisMapping.invertY = true
      cfg.referenceDriftEnabled = false
      cfg.inputSmoothing = 0
      cfg.deadzone = 0
      cfg.pointerSensitivity = 0
      cfg.pointerRotDamping = 1
      cfg.paddleInputGain = 0.3
      cfg.paddleMicroDeadzone = 0.55
      cfg.paddleStillThreshold = 2.5
      cfg.paddleAutoCalibRetain = 0.985
      cfg.paddleAutoCalibBlend = 0.015
      cfg.paddleAutoCalibMaxSteer = 0.06
      cfg.paddleAutoCalibEnabled = true
      cfg.paddleSmoothRetain = 0.72
      cfg.paddleSmoothBlend = 0.28
      cfg.paddleSmoothRetainIdle = 0.86
      cfg.paddleRawSmoothing = 0.35
      cfg.paddleSmoothMax = 2
      cfg.paddleRawDivisor = 100
      cfg.paddleRawDeadband = 8
      cfg.paddleReturnDecay = 0.88
      cfg.paddleScreenScale = 66
      cfg.paddleIntegrateRate = 0
      cfg.paddlePositionGain = 1
      cfg.paddlePositionFollow = 0
      cfg.paddleZeroSnap = 0
      cfg.paddleActiveThreshold = 0
      cfg.paddleIdleVelocityDecay = 0
      cfg.paddleDamping = 1
      cfg.paddleVelocityRetain = 0
      cfg.paddleVelocityBlend = 0
      cfg.paddleVelocityStop = 0
      cfg.paddleMaxVelocity = 0
      cfg.paddleSnapThreshold = 0
    case .pointer:
      cfg.sensorInput = .gyro
      cfg.axisMapping.inputX = .gyroY
      cfg.axisMapping.inputY = .gyroX
      cfg.axisMapping.invertX = false
      cfg.axisMapping.invertY = true
      cfg.deadzone = 0.02
      cfg.pointerSensitivity = 0.03
      cfg.pointerRotDamping = 0.98
      cfg.pointerOutputSmoothing = 0.15
    case .gesture:
      cfg.sensorInput = .gyro
      cfg.axisMapping.inputX = .gyroY
      cfg.axisMapping.inputY = .gyroX
      cfg.axisMapping.invertX = false
      cfg.axisMapping.invertY = true
      cfg.deadzone = 0.02
      cfg.pointerSensitivity = 0.03
      cfg.pointerRotDamping = 0.98
      cfg.pointerOutputSmoothing = 0.15
      cfg.gestureThreshold = 0.6
      cfg.gestureCooldown = 0.4
      cfg.gestureMinRelY = 0.08
    }
    return cfg
  }
}

public struct MotionOutput: Equatable, Sendable {
  public var x: Double = 0
  public var y: Double = 0
  public var didShoot: Bool = false
  public var velocityX: Double = 0
  public var paddleAtRest: Bool = false

  public init(
    x: Double = 0,
    y: Double = 0,
    didShoot: Bool = false,
    velocityX: Double = 0,
    paddleAtRest: Bool = false
  ) {
    self.x = x
    self.y = y
    self.didShoot = didShoot
    self.velocityX = velocityX
    self.paddleAtRest = paddleAtRest
  }
}

public struct MotionDebug: Equatable, Sendable {
  public var rawX: Double = 0
  public var rawY: Double = 0
  public var smoothX: Double = 0
  public var smoothY: Double = 0
  public var relX: Double = 0
  public var relY: Double = 0
  public var velocityX: Double = 0
  public var posX: Double = 0
  public var posY: Double = 0
  public var rotX: Double = 0
  public var rotY: Double = 0
  public var gyroBlockIndex: Int = 0
  public var biasX: Double = 0
  public var paddleRotation: Double = 0
  public var paddleGyroZ: Double = 0
  public var paddleSteer: Double = 0
  public var paddleInput: Double = 0
  public var paddleRawDelta: Double = 0
  public var paddleOffsetLocked: Bool = false
  public var paddleDirection: String = "ŚRODEK"

  public init() {}
}
