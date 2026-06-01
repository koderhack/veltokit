import Foundation

/// Orkiestracja modułów ruchu (pozycja + gest) — API zachowane dla gier i kalibracji.
@MainActor
public final class MotionEngine {
  private let processor: MotionProcessor
  private let gesture: GestureDetector

  public var config: MotionConfig {
    get { processor.config }
    set { processor.config = newValue }
  }

  public private(set) var output = MotionOutput()
  public private(set) var debug = MotionDebug()

  public var isPaddleOffsetSet: Bool { processor.isPaddleOffsetSet }
  public var paddleOffsetRaw: Double { processor.paddleOffsetRaw }
  public var gesturePrimed: Bool { gesture.gesturePrimed }
  public var lastGyroBlockIndex = 0

  private var paddleRotation = 0.0
  private var paddleGyroZ = 0.0

  init(processor: MotionProcessor, gesture: GestureDetector) {
    self.processor = processor
    self.gesture = gesture
  }

  public func setMode(_ mode: MotionMode) {
    guard config.mode != mode else { return }
    config.mode = mode
    resetMotionRuntime()
  }

  public func setRawX(_ value: Double) {
    processor.setRawX(value)
    debug.rawX = value
  }

  public func calibrateCenter() {
    processor.calibrateCenter()
  }

  public func resetCenter() {
    processor.resetCenter()
  }

  public func clearPaddleOffset() {
    resetCenter()
  }

  public func flipPaddleOffsetSign() {
    processor.flipPaddleOffsetSign()
  }

  public func resetPaddleToCenter() {
    resetPaddleMotion()
    resetCenter()
  }

  public func resetPaddleMotion() {
    processor.resetPaddleMotion()
  }

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

  public func resetGestureBaseline() {
    processor.resetGestureBaseline()
    gesture.resetBaseline()
  }

  public func setPaddleSources(rotation: Double, gyroZ: Double) {
    paddleRotation = rotation
    paddleGyroZ = gyroZ
    debug.paddleRotation = rotation
    debug.paddleGyroZ = gyroZ
  }

  public func updatePaddleGyro(yUnscaled: Double, auxiliaryY: Double = 0, gyroBlockIndex: Int = 0) {
    setRawX(yUnscaled)
    debug.rawY = auxiliaryY
    lastGyroBlockIndex = gyroBlockIndex
    debug.gyroBlockIndex = gyroBlockIndex
  }

  public func updateRaw(x: Double, y: Double, gyroBlockIndex: Int = 0) {
    debug.rawX = x
    debug.rawY = y
    lastGyroBlockIndex = gyroBlockIndex
    debug.gyroBlockIndex = gyroBlockIndex
    processor.updateRaw(x: x, y: y)
  }

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
