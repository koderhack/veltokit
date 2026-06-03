import Foundation

/// Tryb czułości wejścia (gamepad) — nie mylić z `MotionMode` gier.
public enum TrikiInputMode: Sendable, Equatable {
  /// Szybka reakcja, niskie progi (domyślny).
  case game
  /// Stabilniejszy kierunek, mniej fałszywych akcji.
  case smooth
}

/// Ramka wejścia dla gier — abstrakcja gamepada (bez surowych osi).
public struct TrikiGameInput: Sendable, Equatable {
  /// Kierunek sterowania w osi głównej, ok. -1…1.
  public var direction: Float = 0
  /// Wartość bezwzględna prędkości (pochodna pozycji).
  public var velocity: Float = 0
  public var isMoving: Bool = false
  public var isShake: Bool = false
  public var isAction: Bool = false
  /// Przechył w lewo (stabilny kierunek).
  public var isTiltLeft: Bool = false
  /// Przechył w prawo.
  public var isTiltRight: Bool = false
  /// Swing — szczyt prędkości i szybki spadek.
  public var isSwing: Bool = false
}

/// Silnik ruchu: prędkość, kierunek, gesty — bez dodatkowego wygładzania (dane już filtrowane na urządzeniu).
public struct TrikiMotionEngine: Sendable {
  public var inputMode: TrikiInputMode = .game

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
    output = TrikiGameInput()
  }

  /// Przetwarza ramki z parsera (tylko `isValid`) — surowe osie nie trafiają do API gry.
  public mutating func ingest(parsed frames: [ParsedMotionData], deltaTime: TimeInterval) {
    guard !frames.isEmpty else { return }
    let dt = Float(min(0.1, max(0.001, deltaTime)))
    let now = Date().timeIntervalSince1970
    let tuning = Tuning(mode: inputMode)

    for frame in frames where frame.isValid {
      processParsed(frame, dt: dt, tuning: tuning, now: now)
    }
  }

  public func getDirection() -> Float { output.direction }
  public func getVelocity() -> Float { output.velocity }
  public func isShake() -> Bool { output.isShake }
  public func isMoving() -> Bool { output.isMoving }

  private mutating func processParsed(
    _ frame: ParsedMotionData,
    dt: Float,
    tuning: Tuning,
    now: TimeInterval
  ) {
    let current = frame.y
    let delta = current - previousPrimary
    let velocity = delta / dt
    let acceleration = (velocity - previousVelocity) / dt

    previousPrimary = current
    previousVelocity = velocity

    let absVel = abs(velocity)
    let directionSign: Float = velocity > tuning.directionDeadzone
      ? 1
      : (velocity < -tuning.directionDeadzone ? -1 : 0)

    if inputMode == .smooth {
      directionLP += tuning.directionAlpha * (current - directionLP)
      output.direction = min(1, max(-1, directionLP))
    } else {
      output.direction = directionSign != 0
        ? directionSign * min(1, absVel * tuning.velocityToDirectionGain)
        : min(1, max(-1, current * tuning.positionDirectionBlend))
    }

    output.velocity = absVel
    output.isMoving = absVel > tuning.moveThreshold

    let shakeSpike = abs(acceleration) > tuning.shakeAccelThreshold
    if (shakeSpike || frame.firmwareShake), now >= shakeCooldownUntil {
      output.isShake = true
      shakeCooldownUntil = now + tuning.shakeCooldown
    } else {
      output.isShake = false
    }

    updateTilt(current: current, tuning: tuning)
    updateSwing(velocity: velocity, absVel: absVel, tuning: tuning)

    let velocityAction = absVel > tuning.actionVelocityThreshold
    let buttonAction = frame.buttonEdge
    let swingAction = output.isSwing
    let wantsAction = buttonAction || velocityAction || swingAction

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
    let swingPeakThreshold: Float
    let swingDropRatio: Float
    let swingMaxFramesAfterPeak: Int

    init(mode: TrikiInputMode) {
      switch mode {
      case .game:
        directionDeadzone = 0.02
        directionAlpha = 0.35
        velocityToDirectionGain = 0.55
        positionDirectionBlend = 0.85
        moveThreshold = 0.08
        shakeAccelThreshold = 1.8
        shakeCooldown = 0.12
        actionVelocityThreshold = 0.65
        actionCooldown = 0.10
        tiltThreshold = 0.22
        tiltStableFrames = 4
        swingPeakThreshold = 0.5
        swingDropRatio = 0.45
        swingMaxFramesAfterPeak = 6
      case .smooth:
        directionDeadzone = 0.05
        directionAlpha = 0.12
        velocityToDirectionGain = 0.35
        positionDirectionBlend = 0.65
        moveThreshold = 0.12
        shakeAccelThreshold = 2.4
        shakeCooldown = 0.18
        actionVelocityThreshold = 0.85
        actionCooldown = 0.14
        tiltThreshold = 0.28
        tiltStableFrames = 8
        swingPeakThreshold = 0.7
        swingDropRatio = 0.5
        swingMaxFramesAfterPeak = 8
      }
    }
  }
}
