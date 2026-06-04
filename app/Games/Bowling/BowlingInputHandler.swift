import Foundation
import VeltoKit

/// Sterowanie Triki: pochylenie lewo/prawo (tiltY) + gest cofnij → rzuć (tiltX + żyro).
final class BowlingInputHandler {
  enum ThrowPhase: Equatable {
    case idle
    case pullingBack
    case ready
    case throwing

    var label: String {
      switch self {
      case .idle: return "Celuj · Triki"
      case .pullingBack: return "COFNIJ rękę"
      case .ready: return "Rzuć!"
      case .throwing: return "…"
      }
    }
  }

  struct ThrowEvent {
    let power: Double
    let lateralPosX: Double
    let releaseSpin: Double
    let releaseTiltVelocity: Double
  }

  /// Pozycja celowania (−1…1) — bez dodatkowego wygładzania (Triki już filtruje).
  private(set) var aimPosX: Double = 0
  private(set) var phase: ThrowPhase = .idle
  private(set) var isPrimed = false
  var invertLateral = false

  private let throwController = DartThrowController()
  private var grip = DartGripMapping.verticalFist
  private var aimNeutralTiltY: Double = 0
  private var throwNeutralTiltX: Double = 0
  private var lockedAimX: Double = 0
  private var lateralDriver = TrikiLateralDriver()
  private let velocityInput = TrikiGameInputManager(mode: .bowling)

  func reset() {
    aimPosX = 0
    lockedAimX = 0
    aimNeutralTiltY = 0
    throwNeutralTiltX = 0
    phase = .idle
    isPrimed = false
    throwController.reset()
    throwController.applyBowlingCalibration()
    lateralDriver.reset()
    velocityInput.reset()
  }

  func prepareForTurnGate() {
    phase = .idle
    isPrimed = false
    throwController.reset(tiltAxis: throwNeutralTiltX)
  }

  func applyAxisMapping(_ axisMapping: MotionAxisMapping) {
    grip = DartGripMapping.from(axisMapping: axisMapping)
  }

  func applyInvisibleCalibration(_ result: BowlingInvisibleCalibrator.Result, currentAim: Double = 0) {
    aimNeutralTiltY = result.lateralNeutral
    throwNeutralTiltX = result.neutralTilt
    throwController.applyCalibration(
      pullDepth: min(result.pullDepth, 0.058),
      throwGyroPeak: min(result.throwGyroPeak, 0.68)
    )
    throwController.reset(tiltAxis: result.neutralTilt)
    let aim = MotionMath.clamp(invertLateral ? -currentAim : currentAim)
    lockedAimX = aim
    aimPosX = aim
  }

  private func rawLean(from input: GameInput) -> Double {
    grip.aimDelta(from: input.sensors, neutralX: aimNeutralTiltY, neutralY: 0).x
  }

  private func updateAim(input: GameInput, deltaTime: TimeInterval) {
    let lean = rawLean(from: input)
    let result = lateralDriver.step(
      current: aimPosX,
      locked: lockedAimX,
      lean: lean,
      input: input,
      deltaTime: deltaTime,
      invert: invertLateral
    )
    lockedAimX = result.locked
    aimPosX = result.aim
  }

  func update(
    input: GameInput,
    deltaTime: TimeInterval,
    aimEnabled: Bool = true,
    throwsEnabled: Bool = true
  ) -> ThrowEvent? {
    if aimEnabled {
      updateAim(input: input, deltaTime: deltaTime)
    }

    guard throwsEnabled else { return nil }

    let velocityFrame = velocityInput.process(input: input, deltaTime: deltaTime)
    if velocityFrame.bowlingThrowTriggered {
      phase = .throwing
      isPrimed = false
      return ThrowEvent(
        power: max(0.35, velocityFrame.bowlingThrowPower),
        lateralPosX: aimPosX,
        releaseSpin: input.trikiVelocity,
        releaseTiltVelocity: velocityFrame.rawVelocity
      )
    }

    let tiltAxis = grip.throwTiltAxis(from: input.sensors, neutral: throwNeutralTiltX)
    let gyroForward = max(0, input.sensors.gyroX)

    if let power = throwController.update(
      tiltAxis: tiltAxis,
      gyroForward: gyroForward,
      deltaTime: deltaTime,
      distanceFactor: 1.15
    ) {
      phase = .throwing
      isPrimed = false
      return ThrowEvent(
        power: power,
        lateralPosX: aimPosX,
        releaseSpin: throwController.lastReleasePeakGyro,
        releaseTiltVelocity: throwController.lastReleaseTiltVelocity
      )
    }

    switch throwController.state {
    case .idle: phase = .idle
    case .pullingBack: phase = .pullingBack
    case .ready: phase = .ready
    case .throwing: phase = .throwing
    }

    isPrimed = throwController.isPrimed
    return nil
  }
}
