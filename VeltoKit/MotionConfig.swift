import Foundation

/// Źródło BLE dla silnika (blok 0 = tilt, blok 1 = żyro).
public enum MotionSensorInput: String, Sendable, Equatable {
  case tilt
  case gyro
}

/// Represents motion config.
public struct MotionConfig: Equatable, Sendable {
  /// Aktywny tryb pracy silnika.
  public var mode: MotionMode = .paddle
  /// Mapowanie źródeł osi na wyjście X/Y.
  public var axisMapping = MotionAxisMapping()
  /// Źródło danych sensorowych preferowane przez runtime.
  public var sensorInput: MotionSensorInput = .gyro

  // Core pipeline
  /// Stores `inputSmoothing` used by this scope.
  public var inputSmoothing: Double = 0.15
  /// Stores `deadzone` used by this scope.
  public var deadzone: Double = 0.01
  /// Stores `referenceBlend` used by this scope.
  public var referenceBlend: Double = 0.005
  /// Stores `referenceRetain` used by this scope.
  public var referenceRetain: Double = 0.995
  /// Wyłączone w `.paddle` — inaczej ref „goni” tilt i relX pojawia się z opóźnieniem.
  public var referenceDriftEnabled: Bool = true

  // Paddle — delta×gain → smooth 0.8/0.2 → posX (absolutna, bez +=)
  /// Stores `paddleInputGain` used by this scope.
  public var paddleInputGain: Double = 0.3
  /// Po gain: |input| poniżej progu → 0 (filtr mikro-szumu IMU, typ. 0.3–0.7).
  public var paddleMicroDeadzone: Double = 0.5
  /// Auto-kalibracja: |raw−offset| poniżej progu = „spokój” (surowe jednostki BLE).
  public var paddleStillThreshold: Double = 3
  /// Stores `paddleAutoCalibRetain` used by this scope.
  public var paddleAutoCalibRetain: Double = 0.98
  /// Stores `paddleAutoCalibBlend` used by this scope.
  public var paddleAutoCalibBlend: Double = 0.02
  /// Stores `paddleAutoCalibEnabled` used by this scope.
  public var paddleAutoCalibEnabled: Bool = true
  /// Auto-offset tylko gdy |smoothX| poniżej (unika „walki” ze sterowaniem).
  public var paddleAutoCalibMaxSteer: Double = 0.06
  /// smooth = smooth * retain + input * blend (ruch — szybciej).
  public var paddleSmoothRetain: Double = 0.72
  /// Stores `paddleSmoothBlend` used by this scope.
  public var paddleSmoothBlend: Double = 0.28
  /// Powrót do środka gdy brak inputu (wolniej = mniej skoków).
  public var paddleSmoothRetainIdle: Double = 0.86
  /// Bezpiecznik runaway — clamp smooth (nie reset do 0).
  public var paddleSmoothMax: Double = 2
  /// delta / divisor przed gain (surowe int16 z BLE).
  public var paddleRawDivisor: Double = 100
  /// Gdy |raw−offset| < deadband → powrót smooth do 0.
  public var paddleRawDeadband: Double = 8
  /// Stores `paddleReturnDecay` used by this scope.
  public var paddleReturnDecay: Double = 0.88
  /// Stores `paddleRawDeadbandRelease` used by this scope.
  public var paddleRawDeadbandRelease: Double = 3
  /// Filtr surowego BLE przed deltą (0.35 ≈ tłumi ±1–2 bez dużego lagu).
  public var paddleRawSmoothing: Double = 0.35
  /// Stores `paddleIntegrateRate` used by this scope.
  public var paddleIntegrateRate: Double = 0
  /// Mnożnik smoothX → offset od środka (UI / gra).
  public var paddleScreenScale: Double = 66
  // Legacy pola zostawione dla zgodności UI DEV (nieużywane w nowym modelu).
  /// Stores `paddlePositionGain` used by this scope.
  public var paddlePositionGain: Double = 2.5
  /// Stores `paddlePositionFollow` used by this scope.
  public var paddlePositionFollow: Double = 0.2
  /// Stores `paddleSpikeThreshold` used by this scope.
  public var paddleSpikeThreshold: Double = 500
  /// Stores `paddleZeroSnap` used by this scope.
  public var paddleZeroSnap: Double = 0.02
  // Legacy pola zostawione dla zgodności UI DEV (nieużywane w nowym modelu).
  /// Stores `paddleGyroAssist` used by this scope.
  public var paddleGyroAssist: Double = 0
  /// Stores `paddleVelocityRetain` used by this scope.
  public var paddleVelocityRetain: Double = 0
  /// Stores `paddleVelocityBlend` used by this scope.
  public var paddleVelocityBlend: Double = 0
  /// Stores `paddleDamping` used by this scope.
  public var paddleDamping: Double = 0.98
  /// Stores `paddleBiasRetain` used by this scope.
  public var paddleBiasRetain: Double = 0.995
  /// Stores `paddleBiasBlend` used by this scope.
  public var paddleBiasBlend: Double = 0.005
  /// Stores `paddleSnapThreshold` used by this scope.
  public var paddleSnapThreshold: Double = 0
  /// Stores `paddleSnapBoost` used by this scope.
  public var paddleSnapBoost: Double = 0
  /// Stores `paddleIdleVelocityDecay` used by this scope.
  public var paddleIdleVelocityDecay: Double = 0
  /// Stores `paddleVelocityStop` used by this scope.
  public var paddleVelocityStop: Double = 0
  /// Stores `paddleBiasLearnMax` used by this scope.
  public var paddleBiasLearnMax: Double = 0
  /// Stores `paddleMaxVelocity` used by this scope.
  public var paddleMaxVelocity: Double = 0
  /// Stores `paddleOutputSmoothing` used by this scope.
  public var paddleOutputSmoothing: Double = 0
  /// Stores `paddleRestHysteresis` used by this scope.
  public var paddleRestHysteresis: Double = 0
  /// Stores `paddleActiveThreshold` used by this scope.
  public var paddleActiveThreshold: Double = 0

  // Core rotation (akumulacja)
  /// Stores `pointerSensitivity` used by this scope.
  public var pointerSensitivity: Double = 0.03
  /// Stores `pointerRotDamping` used by this scope.
  public var pointerRotDamping: Double = 0.98
  /// Stores `pointerOutputSmoothing` used by this scope.
  public var pointerOutputSmoothing: Double = 0.15

  // Gesture / shoot
  /// Stores `gestureThreshold` used by this scope.
  public var gestureThreshold: Double = 0.35
  /// Stores `gestureCooldown` used by this scope.
  public var gestureCooldown: TimeInterval = 0.4
  /// Stores `gestureMinRelY` used by this scope.
  public var gestureMinRelY: Double = 0.08
  /// Minimalna zmiana relY na klatkę (po skali 60 fps) przy rzucie do przodu.
  public var gestureMinThrustSpeed: Double = 0.12
  /// Szybkie cofnięcie (ujemna zmiana relY / klatkę) — uzbraja rzut.
  public var gesturePullSpeed: Double = 0.04
  /// Spadek relY od lokalnego szczytu — uzbraja (niezależnie od znaku osi).
  public var gesturePullbackDelta: Double = 0.07

  /// Tworzy konfigurację z wartościami domyślnymi.
  public init() {}

  /// Domyślna konfiguracja SDK.
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
      cfg.paddleInputGain = 0.34
      cfg.paddleMicroDeadzone = 0.42
      cfg.paddleStillThreshold = 2.5
      cfg.paddleAutoCalibRetain = 0.985
      cfg.paddleAutoCalibBlend = 0.015
      cfg.paddleAutoCalibMaxSteer = 0.06
      cfg.paddleAutoCalibEnabled = true
      cfg.paddleSmoothRetain = 0.58
      cfg.paddleSmoothBlend = 0.42
      cfg.paddleSmoothRetainIdle = 0.76
      cfg.paddleRawSmoothing = 0.22
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
      cfg.referenceDriftEnabled = false
      cfg.inputSmoothing = 0.35
      cfg.deadzone = 0.02
      cfg.pointerSensitivity = 0.045
      cfg.pointerRotDamping = 0.96
      cfg.pointerOutputSmoothing = 0.22
      cfg.gestureThreshold = 0.28
      cfg.gestureCooldown = 0.45
      cfg.gestureMinRelY = 0.10
      cfg.gestureMinThrustSpeed = 0.10
      cfg.gesturePullSpeed = 0.08
      cfg.gesturePullbackDelta = 0.12
    }
    return cfg
  }
}

/// Represents motion output.
public struct MotionOutput: Equatable, Sendable {
  /// Wyjściowa pozycja X po filtrach.
  public var x: Double = 0
  /// Wyjściowa pozycja Y po filtrach.
  public var y: Double = 0
  /// Flaga wykrytego strzału gestem.
  public var didShoot: Bool = false
  /// Dodatkowa metryka prędkości osi X.
  public var velocityX: Double = 0
  /// Informuje, czy paletka jest w spoczynku.
  public var paddleAtRest: Bool = false

  /// Tworzy wynik wyjściowy klatki silnika.
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

/// Represents motion debug.
public struct MotionDebug: Equatable, Sendable {
  /// Surowa wartość osi X.
  public var rawX: Double = 0
  /// Surowa wartość osi Y.
  public var rawY: Double = 0
  /// Wygładzona wartość osi X.
  public var smoothX: Double = 0
  /// Wygładzona wartość osi Y.
  public var smoothY: Double = 0
  /// Delta X względem referencji.
  public var relX: Double = 0
  /// Delta Y względem referencji.
  public var relY: Double = 0
  /// Dodatkowa metryka prędkości X.
  public var velocityX: Double = 0
  /// Pozycja wyjściowa X.
  public var posX: Double = 0
  /// Pozycja wyjściowa Y.
  public var posY: Double = 0
  /// Rotacja zintegrowana X.
  public var rotX: Double = 0
  /// Rotacja zintegrowana Y.
  public var rotY: Double = 0
  /// Indeks bloku żyroskopu użytego w klatce.
  public var gyroBlockIndex: Int = 0
  /// Bieżący bias osi X.
  public var biasX: Double = 0
  /// Odczyt rotacji dla trybu paletki.
  public var paddleRotation: Double = 0
  /// Odczyt gyro Z dla trybu paletki.
  public var paddleGyroZ: Double = 0
  /// Sygnał sterujący paletki po filtrach.
  public var paddleSteer: Double = 0
  /// Sygnał wejściowy paletki przed wygładzeniem.
  public var paddleInput: Double = 0
  /// Surowa delta względem offsetu paletki.
  public var paddleRawDelta: Double = 0
  /// Informuje, czy offset paletki jest ustawiony.
  public var paddleOffsetLocked: Bool = false
  /// Etykieta kierunku paletki dla debug UI.
  public var paddleDirection: String = "ŚRODEK"

  /// Tworzy pustą strukturę danych debugowych.
  public init() {}
}
