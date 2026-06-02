import Foundation

/// Orkiestracja modułów ruchu (pozycja + gest) — API zachowane dla gier i kalibracji.
@MainActor
/// Represents motion engine.
public final class MotionEngine {
  private let processor: MotionProcessor
  private let gesture: GestureDetector

  /// Bieżąca konfiguracja przetwarzania ruchu.
  public var config: MotionConfig {
    get { processor.config }
    set { processor.config = newValue }
  }

  /// Ostatni wynik wyjściowy silnika.
  public private(set) var output = MotionOutput()
  /// Dane debugowe z ostatniej klatki.
  public private(set) var debug = MotionDebug()

  /// Informuje, czy offset paletki został już ustawiony.
  public var isPaddleOffsetSet: Bool { processor.isPaddleOffsetSet }
  /// Aktualny surowy offset paletki.
  public var paddleOffsetRaw: Double { processor.paddleOffsetRaw }
  /// Informuje, czy gest jest uzbrojony do rzutu.
  public var gesturePrimed: Bool { gesture.gesturePrimed }
  /// Indeks ostatniego użytego bloku żyroskopu.
  public var lastGyroBlockIndex = 0

  private var paddleRotation = 0.0
  private var paddleGyroZ = 0.0

  init(processor: MotionProcessor, gesture: GestureDetector) {
    self.processor = processor
    self.gesture = gesture
  }

  /// Ustawia tryb pracy i resetuje runtime silnika.
  public func setMode(_ mode: MotionMode) {
    guard config.mode != mode else { return }
    config.mode = mode
    resetMotionRuntime()
  }

  /// Ustawia surową próbkę X dla trybu paletki.
  public func setRawX(_ value: Double) {
    processor.setRawX(value)
    debug.rawX = value
  }

  /// Kalibruje neutralne położenie paletki.
  public func calibrateCenter() {
    processor.calibrateCenter()
  }

  /// Czyści offset i wraca do stanu niekalibrowanego.
  public func resetCenter() {
    processor.resetCenter()
  }

  /// Alias zgodności do czyszczenia offsetu paletki.
  public func clearPaddleOffset() {
    resetCenter()
  }

  /// Odwraca znak offsetu paletki.
  public func flipPaddleOffsetSign() {
    processor.flipPaddleOffsetSign()
  }

  /// Resetuje ruch paletki i ponownie centruje.
  public func resetPaddleToCenter() {
    resetPaddleMotion()
    resetCenter()
  }

  /// Resetuje tylko dynamikę paletki.
  public func resetPaddleMotion() {
    processor.resetPaddleMotion()
  }

  /// Resetuje cały stan runtime silnika.
  public func resetState() {
    resetMotionRuntime()
  }

  private func resetMotionRuntime() {
    processor.resetAll()
    gesture.resetBaseline()
    output = MotionOutput()
    debug = MotionDebug()
    lastGyroBlockIndex = 0
    paddleRotation = 0
    paddleGyroZ = 0
  }

  /// Resetuje referencję bazową detektora gestu.
  public func resetGestureBaseline() {
    processor.resetGestureBaseline()
    gesture.resetBaseline()
  }

  /// Ustawia źródła używane przez tryb paletki.
  public func setPaddleSources(rotation: Double, gyroZ: Double) {
    paddleRotation = rotation
    paddleGyroZ = gyroZ
    debug.paddleRotation = rotation
    debug.paddleGyroZ = gyroZ
  }

  /// Aktualizuje wejście paletki surową osią Y z BLE.
  public func updatePaddleGyro(yUnscaled: Double, auxiliaryY: Double = 0, gyroBlockIndex: Int = 0) {
    setRawX(yUnscaled)
    debug.rawY = auxiliaryY
    lastGyroBlockIndex = gyroBlockIndex
    debug.gyroBlockIndex = gyroBlockIndex
  }

  /// Aktualizuje surowe wejście X/Y dla bieżącej klatki.
  public func updateRaw(x: Double, y: Double, gyroBlockIndex: Int = 0) {
    debug.rawX = x
    debug.rawY = y
    lastGyroBlockIndex = gyroBlockIndex
    debug.gyroBlockIndex = gyroBlockIndex
    processor.updateRaw(x: x, y: y)
  }

  /// Przetwarza jedną klatkę ruchu.
  ///
  /// - Parameter deltaTime: Długość kroku symulacji w sekundach.
  public func updateFrame(deltaTime: TimeInterval) {
    let cfg = config
    let dt = min(0.05, max(0, deltaTime))
    let frameScale = dt * 60

    gesture.resetFrame()
    var didShoot = false

    switch cfg.mode {
    case .paddle:
      processor.updatePaddle(frameScale: frameScale)
      gesture.suppressPrimedDisplay()
    case .pointer:
      processor.updateRotationPointer(frameScale: frameScale)
      processor.preparePointerFrame()
      processor.applyPointerOutput(gestureArmed: false)
      gesture.suppressPrimedDisplay()
    case .gesture:
      processor.updateRotationPointer(frameScale: frameScale)
      processor.preparePointerFrame()
      processor.applyPointerOutput(gestureArmed: gesture.gesturePrimed)
      gesture.detect(relY: processor.relY, cfg: cfg, frameScale: frameScale)
      didShoot = gesture.didThrow
    }

    output = MotionOutput(
      x: processor.posX,
      y: processor.posY,
      didShoot: didShoot,
      velocityX: 0,
      paddleAtRest: cfg.mode == .paddle ? abs(processor.debugSmoothX) < 0.02 : false
    )

    refreshDebug()
  }

  /// Stores `lastGestureThrowPower` used by this scope.
  var lastGestureThrowPower: Double { gesture.lastThrowPower }

  private func refreshDebug() {
    debug.smoothX = processor.debugSmoothX
    debug.smoothY = processor.debugSmoothY
    debug.relX = processor.relX
    debug.relY = processor.relY
    debug.posX = processor.posX
    debug.posY = processor.posY
    debug.biasX = processor.debugBiasX
    debug.paddleInput = processor.debugPaddleInput
    debug.paddleRawDelta = processor.debugPaddleRawDelta
    debug.paddleSteer = processor.debugPaddleSteer
    debug.paddleOffsetLocked = processor.debugPaddleOffsetLocked
    debug.paddleDirection = processor.paddleDirectionLabel()
    debug.rotX = processor.debugRotX
    debug.rotY = processor.debugRotY
  }
}
