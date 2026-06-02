import Foundation

/// Surowy BLE → pozycja (offset, wygładzanie, posX).
@MainActor
/// Przetwarza surowe wejście ruchu do postaci używanej przez `MotionEngine`.
final class MotionProcessor {
  /// Konfiguracja filtrów i mapowania ruchu.
  var config = MotionConfig.default

  private var rawX = 0.0
  private var filteredRawX = 0.0
  private var offsetX = 0.0
  private var offsetBootstrapped = false
  private var smoothX = 0.0
  private(set) var posX = 0.0
  private(set) var posY = 0.0
  private(set) var relX = 0.0
  private(set) var relY = 0.0
  private var microDeadzoneActive = false
  private(set) var paddleOffsetRaw: Double = 0

  private var smoothInputX = 0.0
  private var smoothInputY = 0.0
  private var rotX = 0.0
  private var rotY = 0.0
  private var refX = 0.0
  private var refY = 0.0

  /// Informuje, czy offset paletki został zainicjalizowany.
  var isPaddleOffsetSet: Bool { offsetBootstrapped }

  /// Ustawia surową próbkę osi X.
  func setRawX(_ value: Double) {
    rawX = value
    let blend = min(1, max(0, config.paddleRawSmoothing))
    if !offsetBootstrapped {
      filteredRawX = value
    } else {
      filteredRawX = filteredRawX * (1 - blend) + value * blend
    }
  }

  /// Kalibruje bieżącą pozycję jako neutralną.
  func calibrateCenter() {
    offsetX = filteredRawX
    paddleOffsetRaw = filteredRawX
    offsetBootstrapped = true
    smoothX = 0
    posX = 0
    relX = 0
  }

  /// Czyści offset i stan centrujący paletki.
  func resetCenter() {
    offsetBootstrapped = false
    offsetX = 0
    paddleOffsetRaw = 0
    smoothX = 0
    posX = 0
  }

  /// Odwraca znak aktualnego offsetu paletki.
  func flipPaddleOffsetSign() {
    guard offsetBootstrapped else { return }
    offsetX = -offsetX
    paddleOffsetRaw = offsetX
  }

  /// Resetuje tylko stan dynamiczny paletki.
  func resetPaddleMotion() {
    smoothX = 0
    posX = 0
    relX = 0
  }

  /// Resetuje bazę referencyjną dla trybu gestu.
  func resetGestureBaseline() {
    refX = rotX
    refY = rotY
    relX = 0
    relY = 0
    posX = 0
    posY = 0
  }

  /// Resetuje kompletny stan procesora.
  func resetAll() {
    rawX = 0
    filteredRawX = 0
    offsetX = 0
    offsetBootstrapped = false
    smoothX = 0
    posX = 0
    posY = 0
    microDeadzoneActive = false
    smoothInputX = 0
    smoothInputY = 0
    rotX = 0
    rotY = 0
    refX = 0
    refY = 0
    relX = 0
    relY = 0
    paddleOffsetRaw = 0
  }

  /// Aktualizuje wejście osi X/Y po wstępnym wygładzeniu.
  func updateRaw(x: Double, y: Double) {
    let blend = min(1, max(0, config.inputSmoothing))
    smoothInputX = smoothInputX * (1 - blend) + x * blend
    smoothInputY = smoothInputY * (1 - blend) + y * blend
  }

  /// Aktualizuje wyjście w trybie paletki.
  func updatePaddle(frameScale: Double) {
    bootstrapOffsetIfNeeded()

    let sample = filteredRawX
    var rawDelta = sample - offsetX
    let spikeCap = config.paddleSpikeThreshold
    if abs(rawDelta) > spikeCap {
      rawDelta = spikeCap * (rawDelta > 0 ? 1 : -1)
    }

    let isStill = abs(rawDelta) < config.paddleStillThreshold
      && abs(smoothX) < config.paddleAutoCalibMaxSteer
    if config.paddleAutoCalibEnabled, isStill {
      let retain = min(1, max(0, config.paddleAutoCalibRetain))
      let blend = min(1, max(0, config.paddleAutoCalibBlend))
      offsetX = offsetX * retain + sample * blend
      paddleOffsetRaw = offsetX
      rawDelta = sample - offsetX
    }

    let delta = rawDelta / max(1, config.paddleRawDivisor)
    let input = delta * config.paddleInputGain
    let stableInput = stablePaddleInput(input)

    let scale = max(0.001, frameScale)
    if stableInput != 0 {
      let retain = pow(config.paddleSmoothRetain, scale)
      smoothX = smoothX * retain + stableInput * (1 - retain)
    } else {
      let retainIdle = pow(config.paddleSmoothRetainIdle, scale)
      smoothX *= retainIdle
      if abs(smoothX) < 0.02 { smoothX = 0 }
    }

    let cap = max(0.1, config.paddleSmoothMax)
    smoothX = min(cap, max(-cap, smoothX))
    posX = smoothX
    relX = smoothX
    posY = 0
    relY = 0
  }

  /// Integruje ruch i referencję dla trybu pointer/gesture.
  func updateRotationPointer(frameScale: Double) {
    let cfg = config
    rotX += smoothInputX * cfg.pointerSensitivity * frameScale
    rotY += smoothInputY * cfg.pointerSensitivity * frameScale
    if cfg.pointerRotDamping > 0, cfg.pointerRotDamping < 1 {
      rotX *= pow(cfg.pointerRotDamping, frameScale)
      rotY *= pow(cfg.pointerRotDamping, frameScale)
    }
    rotX = MotionMath.clamp(rotX)
    rotY = MotionMath.clamp(rotY)
    if cfg.referenceDriftEnabled {
      refX = refX * cfg.referenceRetain + rotX * cfg.referenceBlend
      refY = refY * cfg.referenceRetain + rotY * cfg.referenceBlend
    }
    relX = rotX - refX
    relY = rotY - refY
    posX = relX
  }

  /// Nakłada wygładzanie wyjścia pointer z uwzględnieniem stanu gestu.
  func applyPointerOutput(gestureArmed: Bool) {
    let cfg = config
    var out = min(1, max(0, cfg.pointerOutputSmoothing))
    if cfg.mode == .gesture, gestureArmed {
      out *= 0.28
    }
    posX = posX * (1 - out) + relX * out
    posY = posY * (1 - out) + relY * out
    posX = MotionMath.clamp(posX)
    posY = MotionMath.clamp(posY)
  }

  /// Przygotowuje stan klatki wskaźnika przed finalnym outputem.
  func preparePointerFrame() {
    posY = 0
  }

  // MARK: - Debug samples

  /// Stores `debugRawX` used by this scope.
  var debugRawX: Double { rawX }
  /// Stores `debugRawY` used by this scope.
  var debugRawY: Double { smoothInputY }
  /// Stores `debugSmoothX` used by this scope.
  var debugSmoothX: Double { smoothX }
  /// Stores `debugSmoothY` used by this scope.
  var debugSmoothY: Double { smoothInputY }
  /// Stores `debugBiasX` used by this scope.
  var debugBiasX: Double { offsetX }
  /// Stores `debugPaddleInput` used by this scope.
  var debugPaddleInput: Double { rawX - offsetX }
  /// Stores `debugPaddleRawDelta` used by this scope.
  var debugPaddleRawDelta: Double { rawX - offsetX }
  /// Stores `debugPaddleSteer` used by this scope.
  var debugPaddleSteer: Double { smoothX }
  /// Stores `debugPaddleOffsetLocked` used by this scope.
  var debugPaddleOffsetLocked: Bool { offsetBootstrapped }
  /// Stores `debugRotX` used by this scope.
  var debugRotX: Double { rotX }
  /// Stores `debugRotY` used by this scope.
  var debugRotY: Double { rotY }

  /// Zwraca etykietę kierunku paletki dla debug UI.
  func paddleDirectionLabel() -> String {
    if abs(smoothX) < 0.06 { return "ŚRODEK" }
    return smoothX < 0 ? "LEWO" : "PRAWO"
  }

  private func bootstrapOffsetIfNeeded() {
    guard !offsetBootstrapped else { return }
    offsetX = filteredRawX
    paddleOffsetRaw = filteredRawX
    offsetBootstrapped = true
  }

  private func stablePaddleInput(_ input: Double) -> Double {
    let enter = config.paddleMicroDeadzone
    let exit = enter * 0.65
    if microDeadzoneActive {
      if abs(input) < exit { microDeadzoneActive = false }
    } else if abs(input) > enter {
      microDeadzoneActive = true
    }
    return microDeadzoneActive ? input : 0
  }
}
