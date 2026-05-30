import Foundation

/// Paletka: auto-offset w spoczynku → delta×gain → micro-DZ → smooth → posX.
@MainActor
public final class MotionEngine {
  public var config = MotionConfig.default
  public private(set) var output = MotionOutput()
  public private(set) var debug = MotionDebug()

  private var rawX = 0.0
  private var filteredRawX = 0.0
  private var offsetX = 0.0
  private var offsetBootstrapped = false
  private var smoothX = 0.0
  private var posX = 0.0
  private var microDeadzoneActive = false
  public private(set) var paddleOffsetRaw: Double = 0

  private var smoothInputX = 0.0
  private var smoothInputY = 0.0
  private var refX = 0.0
  private var refY = 0.0
  private var relX = 0.0
  private var relY = 0.0
  private var posY = 0.0
  private var rotX = 0.0
  private var rotY = 0.0
  private var lastShotAt: TimeInterval = 0
  private var gestureArmed = true
  public var lastGyroBlockIndex = 0

  public var isPaddleOffsetSet: Bool { offsetBootstrapped }

  public init() {}

  public func setMode(_ mode: MotionMode) {
    guard config.mode != mode else { return }
    config.mode = mode
    resetMotionRuntime()
  }

  public func setRawX(_ value: Double) {
    rawX = value
    debug.rawX = value
    let blend = min(1, max(0, config.paddleRawSmoothing))
    if !offsetBootstrapped {
      filteredRawX = value
    } else {
      filteredRawX = filteredRawX * (1 - blend) + value * blend
    }
  }

  /// Natychmiastowy snap środka (DEV / ręczny override).
  public func calibrateCenter() {
    offsetX = filteredRawX
    paddleOffsetRaw = filteredRawX
    offsetBootstrapped = true
    smoothX = 0
    posX = 0
    relX = 0
  }

  public func resetCenter() {
    offsetBootstrapped = false
    offsetX = 0
    paddleOffsetRaw = 0
    smoothX = 0
    posX = 0
  }

  public func clearPaddleOffset() {
    resetCenter()
  }

  public func flipPaddleOffsetSign() {
    guard offsetBootstrapped else { return }
    offsetX = -offsetX
    paddleOffsetRaw = offsetX
  }

  public func resetPaddleToCenter() {
    resetPaddleMotion()
    resetCenter()
  }

  public func resetPaddleMotion() {
    smoothX = 0
    posX = 0
    relX = 0
  }

  public func resetState() {
    resetMotionRuntime()
  }

  private func resetMotionRuntime() {
    rawX = 0
    filteredRawX = 0
    offsetX = 0
    offsetBootstrapped = false
    smoothX = 0
    posX = 0
    microDeadzoneActive = false
    smoothInputX = 0
    smoothInputY = 0
    refX = 0
    refY = 0
    relX = 0
    relY = 0
    posY = 0
    rotX = 0
    rotY = 0
    output = MotionOutput()
    debug = MotionDebug()
    lastShotAt = 0
    gestureArmed = true
  }

  public func setPaddleSources(rotation: Double, gyroZ: Double) {
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
    let blend = min(1, max(0, config.inputSmoothing))
    smoothInputX = smoothInputX * (1 - blend) + x * blend
    smoothInputY = smoothInputY * (1 - blend) + y * blend
  }

  public func updateFrame(deltaTime: TimeInterval) {
    let cfg = config
    let dt = min(0.05, max(0, deltaTime))
    let frameScale = dt * 60

    var didShoot = false

    switch cfg.mode {
    case .paddle:
      updatePaddle()
      posY = 0
      relY = 0
    case .pointer:
      updateRotationPointer(cfg: cfg, frameScale: frameScale)
      posY = 0
      relY = rotY - refY
      updatePointer(relX: relX, relY: relY, cfg: cfg)
    case .gesture:
      updateRotationPointer(cfg: cfg, frameScale: frameScale)
      posY = 0
      relY = rotY - refY
      updatePointer(relX: relX, relY: relY, cfg: cfg)
      didShoot = detectGestureShot(relY: relY, cfg: cfg)
    }

    output = MotionOutput(
      x: posX,
      y: posY,
      didShoot: didShoot,
      velocityX: 0,
      paddleAtRest: cfg.mode == .paddle ? abs(smoothX) < 0.02 : false
    )

    debug.smoothX = smoothX
    debug.smoothY = smoothInputY
    debug.relX = relX
    debug.relY = relY
    debug.posX = posX
    debug.posY = posY
    debug.biasX = offsetX
    debug.paddleInput = rawX - offsetX
    debug.paddleRawDelta = rawX - offsetX
    debug.paddleSteer = smoothX
    debug.paddleOffsetLocked = offsetBootstrapped
    debug.paddleDirection = paddleDirectionLabel(smoothX)
  }

  private func paddleDirectionLabel(_ value: Double) -> String {
    if abs(value) < 0.06 { return "ŚRODEK" }
    return value < 0 ? "LEWO" : "PRAWO"
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

  private func updatePaddle() {
    bootstrapOffsetIfNeeded()

    let sample = filteredRawX
    var rawDelta = sample - offsetX
    if abs(rawDelta) > config.paddleSpikeThreshold { return }

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

    if stableInput != 0 {
      smoothX = smoothX * config.paddleSmoothRetain + stableInput * config.paddleSmoothBlend
    } else {
      smoothX *= config.paddleSmoothRetainIdle
      if abs(smoothX) < 0.02 { smoothX = 0 }
    }

    let cap = max(0.1, config.paddleSmoothMax)
    smoothX = min(cap, max(-cap, smoothX))
    posX = smoothX
    relX = smoothX
  }

  private func updateRotationPointer(cfg: MotionConfig, frameScale: Double) {
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

  private func updatePointer(relX: Double, relY: Double, cfg: MotionConfig) {
    let out = min(1, max(0, cfg.pointerOutputSmoothing))
    posX = posX * (1 - out) + relX * out
    posY = posY * (1 - out) + relY * out
    posX = MotionMath.clamp(posX)
    posY = MotionMath.clamp(posY)
  }

  private func detectGestureShot(relY: Double, cfg: MotionConfig) -> Bool {
    let now = Date().timeIntervalSince1970
    guard gestureArmed else {
      if relY < cfg.gestureMinRelY * 0.5 { gestureArmed = true }
      return false
    }
    guard relY > cfg.gestureThreshold else { return false }
    guard now - lastShotAt >= cfg.gestureCooldown else { return false }
    lastShotAt = now
    gestureArmed = false
    return true
  }
}
