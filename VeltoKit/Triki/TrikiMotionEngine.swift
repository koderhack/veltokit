import Foundation

/// Tryb czułości wejścia (gamepad) — nie mylić z `MotionMode` gier.
public enum TrikiInputMode: Sendable, Equatable {
  case game
  case smooth
}

/// Ramka wejścia dla gier — abstrakcja gamepada (bez surowych osi).
public struct TrikiGameInput: Sendable, Equatable {
  public var direction: Float = 0
  public var velocity: Float = 0
  public var isMoving: Bool = false
  public var isShake: Bool = false
  public var isAction: Bool = false
  public var isTiltLeft: Bool = false
  public var isTiltRight: Bool = false
  public var isSwing: Bool = false
  /// Wykryty tryb notify BLE (adaptacja przetwarzania).
  public var bleMode: TrikiBLEMode = .unknown
  /// `true` w low power — UI może pokazać „czeka na ruch”.
  public var isIdleLowPower: Bool = false
}

/// Adaptacyjny silnik ruchu — strategia zależy od `bleMode` i `inputMode`.
public struct TrikiMotionEngine: Sendable {
  public var inputMode: TrikiInputMode = .game
  public var bleMode: TrikiBLEMode = .unknown

  private var previousPrimary: Float = 0
  private var previousVelocity: Float = 0
  private var directionLP: Float = 0
  private var tiltSignStreak: Int = 0
  private var lastTiltSign: Int = 0
  private var swingArmed = false
  private var swingPeakVelocity: Float = 0
  private var framesSinceSwingPeak = 0

  private var shakeCooldownUntil: TimeInterval = 0
  private var actionCooldownUntil: TimeInterval = 0

  public private(set) var output = TrikiGameInput()

  public init() {}

  public mutating func reset() {
    previousPrimary = 0
    previousVelocity = 0
    directionLP = 0
    tiltSignStreak = 0
    lastTiltSign = 0
    swingArmed = false
    swingPeakVelocity = 0
    framesSinceSwingPeak = 0
    shakeCooldownUntil = 0
    actionCooldownUntil = 0
    bleMode = .unknown
    output = TrikiGameInput()
  }

  public mutating func setBLEMode(_ mode: TrikiBLEMode) {
    bleMode = mode
    output.bleMode = mode
    output.isIdleLowPower = mode == .lowPower
  }

  public mutating func ingest(parsed frames: [ParsedMotionData], deltaTime: TimeInterval) {
    guard !frames.isEmpty else { return }
    let dt = Float(min(0.1, max(0.001, deltaTime)))
    let now = Date().timeIntervalSince1970
    output.bleMode = bleMode
    output.isIdleLowPower = bleMode == .lowPower

    for frame in frames where frame.isValid {
      switch bleMode {
      case .fast:
        processVelocityInput(frame, dt: dt, now: now)
      case .normal:
        processDirectionalInput(frame, dt: dt, now: now)
      case .lowPower:
        processMinimalInput(frame, dt: dt, now: now)
      case .unknown:
        processDirectionalInput(frame, dt: dt, now: now)
      }
    }
  }

  public func getDirection() -> Float { output.direction }
  public func getVelocity() -> Float { output.velocity }
  public func isShake() -> Bool { output.isShake }
  public func isMoving() -> Bool { output.isMoving }

  // MARK: - FAST — velocity, swing, pełna responsywność

  private mutating func processVelocityInput(
    _ frame: ParsedMotionData,
    dt: Float,
    now: TimeInterval
  ) {
    let tuning = Tuning(input: inputMode, ble: .fast)
    let current = frame.y
    let velocity = (current - previousPrimary) / dt
    let acceleration = (velocity - previousVelocity) / dt
    previousPrimary = current
    previousVelocity = velocity

    let absVel = abs(velocity)
    let sign: Float = velocity > tuning.directionDeadzone
      ? 1
      : (velocity < -tuning.directionDeadzone ? -1 : 0)

    output.direction = sign != 0
      ? sign * min(1, absVel * tuning.velocityToDirectionGain)
      : min(1, max(-1, current * tuning.positionDirectionBlend))
    output.velocity = absVel
    output.isMoving = absVel > tuning.moveThreshold

    applyShake(frame: frame, acceleration: acceleration, tuning: tuning, now: now)
    updateTilt(current: current, tuning: tuning)
    updateSwing(velocity: velocity, absVel: absVel, tuning: tuning)
    applyAction(frame: frame, absVel: absVel, tuning: tuning, now: now, allowVelocityAction: true)
  }

  // MARK: - NORMAL — kierunek + lekka stabilizacja

  private mutating func processDirectionalInput(
    _ frame: ParsedMotionData,
    dt: Float,
    now: TimeInterval
  ) {
    let tuning = Tuning(input: inputMode, ble: .normal)
    let current = frame.y
    let velocity = (current - previousPrimary) / dt
    let acceleration = (velocity - previousVelocity) / dt
    previousPrimary = current
    previousVelocity = velocity * 0.5

    directionLP += tuning.directionAlpha * (current - directionLP)
    output.direction = min(1, max(-1, directionLP))
    output.velocity = abs(velocity) * 0.6
    output.isMoving = abs(current) > tuning.moveThreshold || abs(velocity) > tuning.moveThreshold

    applyShake(frame: frame, acceleration: acceleration, tuning: tuning, now: now)
    updateTilt(current: current, tuning: tuning)
    updateSwing(velocity: velocity, absVel: abs(velocity), tuning: tuning)
    applyAction(frame: frame, absVel: abs(velocity), tuning: tuning, now: now, allowVelocityAction: false)
  }

  // MARK: - LOW POWER — tilt / shake, bez velocity gameplay

  private mutating func processMinimalInput(
    _ frame: ParsedMotionData,
    dt: Float,
    now: TimeInterval
  ) {
    let tuning = Tuning(input: inputMode, ble: .lowPower)
    let current = frame.y
    previousPrimary = current
    previousVelocity = 0

    output.velocity = 0
    output.isMoving = false
    output.isSwing = false
    swingArmed = false

    let sign: Float = current > tuning.tiltThreshold
      ? 1
      : (current < -tuning.tiltThreshold ? -1 : 0)
    output.direction = sign * 0.35

    applyShake(frame: frame, acceleration: 0, tuning: tuning, now: now)
    updateTilt(current: current, tuning: tuning)
    applyAction(frame: frame, absVel: 0, tuning: tuning, now: now, allowVelocityAction: false)
  }

  // MARK: - Shared helpers

  private mutating func applyShake(
    frame: ParsedMotionData,
    acceleration: Float,
    tuning: Tuning,
    now: TimeInterval
  ) {
    let spike = abs(acceleration) > tuning.shakeAccelThreshold
    if (spike || frame.firmwareShake), now >= shakeCooldownUntil {
      output.isShake = true
      shakeCooldownUntil = now + tuning.shakeCooldown
    } else {
      output.isShake = false
    }
  }

  private mutating func applyAction(
    frame: ParsedMotionData,
    absVel: Float,
    tuning: Tuning,
    now: TimeInterval,
    allowVelocityAction: Bool
  ) {
    let velocityAction = allowVelocityAction && absVel > tuning.actionVelocityThreshold
    let wantsAction = frame.buttonEdge || velocityAction || output.isSwing
    if wantsAction, now >= actionCooldownUntil {
      output.isAction = true
      actionCooldownUntil = now + tuning.actionCooldown
    } else {
      output.isAction = false
    }
  }

  private mutating func updateTilt(current: Float, tuning: Tuning) {
    let sign: Int
    if current > tuning.tiltThreshold { sign = 1 }
    else if current < -tuning.tiltThreshold { sign = -1 }
    else { sign = 0 }

    if sign != 0, sign == lastTiltSign {
      tiltSignStreak += 1
    } else {
      tiltSignStreak = sign == 0 ? 0 : 1
      lastTiltSign = sign
    }

    let stable = tiltSignStreak >= tuning.tiltStableFrames
    output.isTiltLeft = stable && sign < 0
    output.isTiltRight = stable && sign > 0
  }

  private mutating func updateSwing(velocity: Float, absVel: Float, tuning: Tuning) {
    guard tuning.swingEnabled else {
      output.isSwing = false
      return
    }

    if absVel > tuning.swingPeakThreshold {
      swingArmed = true
      swingPeakVelocity = max(swingPeakVelocity, absVel)
      framesSinceSwingPeak = 0
      output.isSwing = false
      return
    }

    if swingArmed {
      framesSinceSwingPeak += 1
      let dropped = absVel < swingPeakVelocity * tuning.swingDropRatio
      if dropped, framesSinceSwingPeak <= tuning.swingMaxFramesAfterPeak {
        output.isSwing = true
        swingArmed = false
        swingPeakVelocity = 0
        return
      }
      if framesSinceSwingPeak > tuning.swingMaxFramesAfterPeak {
        swingArmed = false
        swingPeakVelocity = 0
      }
    }
    output.isSwing = false
  }

  private struct Tuning {
    let directionDeadzone: Float
    let directionAlpha: Float
    let velocityToDirectionGain: Float
    let positionDirectionBlend: Float
    let moveThreshold: Float
    let shakeAccelThreshold: Float
    let shakeCooldown: TimeInterval
    let actionVelocityThreshold: Float
    let actionCooldown: TimeInterval
    let tiltThreshold: Float
    let tiltStableFrames: Int
    let swingEnabled: Bool
    let swingPeakThreshold: Float
    let swingDropRatio: Float
    let swingMaxFramesAfterPeak: Int

    init(input: TrikiInputMode, ble: TrikiBLEMode) {
      let base = Base(input: input)
      switch ble {
      case .fast:
        directionDeadzone = base.directionDeadzone
        directionAlpha = base.directionAlpha
        velocityToDirectionGain = base.velocityGain
        positionDirectionBlend = base.positionBlend
        moveThreshold = base.moveThreshold * 0.85
        shakeAccelThreshold = base.shakeAccel * 0.9
        shakeCooldown = base.shakeCooldown
        actionVelocityThreshold = base.actionVelocity * 0.9
        actionCooldown = base.actionCooldown
        tiltThreshold = base.tiltThreshold
        tiltStableFrames = max(2, base.tiltFrames - 1)
        swingEnabled = true
        swingPeakThreshold = base.swingPeak * 0.9
        swingDropRatio = base.swingDrop
        swingMaxFramesAfterPeak = base.swingFrames
      case .normal:
        directionDeadzone = base.directionDeadzone * 1.2
        directionAlpha = min(0.28, base.directionAlpha + 0.08)
        velocityToDirectionGain = base.velocityGain * 0.5
        positionDirectionBlend = base.positionBlend
        moveThreshold = base.moveThreshold
        shakeAccelThreshold = base.shakeAccel
        shakeCooldown = base.shakeCooldown
        actionVelocityThreshold = .infinity
        actionCooldown = base.actionCooldown
        tiltThreshold = base.tiltThreshold
        tiltStableFrames = base.tiltFrames
        swingEnabled = true
        swingPeakThreshold = base.swingPeak * 1.15
        swingDropRatio = base.swingDrop
        swingMaxFramesAfterPeak = base.swingFrames
      case .lowPower, .unknown:
        directionDeadzone = 0.08
        directionAlpha = 0.08
        velocityToDirectionGain = 0
        positionDirectionBlend = 0.4
        moveThreshold = 0.2
        shakeAccelThreshold = base.shakeAccel * 0.75
        shakeCooldown = base.shakeCooldown * 1.2
        actionVelocityThreshold = .infinity
        actionCooldown = base.actionCooldown * 1.1
        tiltThreshold = base.tiltThreshold * 0.85
        tiltStableFrames = max(2, base.tiltFrames - 2)
        swingEnabled = false
        swingPeakThreshold = 1
        swingDropRatio = 0.5
        swingMaxFramesAfterPeak = 0
      }
    }

    private struct Base {
      let directionDeadzone: Float
      let directionAlpha: Float
      let velocityGain: Float
      let positionBlend: Float
      let moveThreshold: Float
      let shakeAccel: Float
      let shakeCooldown: TimeInterval
      let actionVelocity: Float
      let actionCooldown: TimeInterval
      let tiltThreshold: Float
      let tiltFrames: Int
      let swingPeak: Float
      let swingDrop: Float
      let swingFrames: Int

      init(input: TrikiInputMode) {
        switch input {
        case .game:
          directionDeadzone = 0.02
          directionAlpha = 0.22
          velocityGain = 0.55
          positionBlend = 0.85
          moveThreshold = 0.08
          shakeAccel = 1.8
          shakeCooldown = 0.12
          actionVelocity = 0.65
          actionCooldown = 0.10
          tiltThreshold = 0.22
          tiltFrames = 4
          swingPeak = 0.5
          swingDrop = 0.45
          swingFrames = 6
        case .smooth:
          directionDeadzone = 0.05
          directionAlpha = 0.12
          velocityGain = 0.35
          positionBlend = 0.65
          moveThreshold = 0.12
          shakeAccel = 2.4
          shakeCooldown = 0.18
          actionVelocity = 0.85
          actionCooldown = 0.14
          tiltThreshold = 0.28
          tiltFrames = 8
          swingPeak = 0.7
          swingDrop = 0.5
          swingFrames = 8
        }
      }
    }
  }
}
