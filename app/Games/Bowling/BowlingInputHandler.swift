import Foundation
import VeltoKit

/// Sterowanie Triki: pochylenie lewo/prawo (tiltY) + gest cofnij → rzuć (tiltX + żyro).
final class BowlingInputHandler {
  /// Opisuje stan wejścia gracza podczas przygotowania i wykonania rzutu.
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

  /// Zawiera komplet danych emitowanych w chwili zwolnienia kuli.
  struct ThrowEvent {
    let power: Double
    let lateralPosX: Double
    let releaseSpin: Double
    let releaseTiltVelocity: Double
  }

  private(set) var smoothedPosX: Double = 0
  private(set) var phase: ThrowPhase = .idle
  private(set) var isPrimed = false
  /// Odwraca poziome sterowanie celowaniem, gdy aktywne jest ustawienie preferencji gracza.
  var invertLateral = false

  private let throwController = DartThrowController()
  private var grip = DartGripMapping.verticalFist
  private var aimNeutralTiltY: Double = 0
  private var throwNeutralTiltX: Double = 0

  /// Ustawiona pozycja kuli — zostaje, gdy stoisz prosto.
  private var lockedAimX: Double = 0
  /// Wygładzone pochylenie (filtruje drgania sensora).
  private var filteredLean: Double = 0

  private let lateralGain = 2.1
  private let leanFilterAlpha = 0.07
  /// Poniżej — uznaj, że stoisz stabilnie; kula się nie rusza.
  private let leanHoldThreshold = 0.011
  private let maxAimStepPerFrame = 0.014

  /// Resetuje stan wejścia i przywraca punkt startowy celowania oraz rzutu.
  func reset() {
    smoothedPosX = 0
    lockedAimX = 0
    filteredLean = 0
    aimNeutralTiltY = 0
    throwNeutralTiltX = 0
    phase = .idle
    isPrimed = false
    throwController.reset()
    throwController.applyBowlingCalibration()
  }

  /// Przygotowuje handler na start nowej tury bez kasowania kalibracji osi.
  func prepareForTurnGate() {
    phase = .idle
    isPrimed = false
    throwController.reset(tiltAxis: throwNeutralTiltX)
  }

  /// Aktualizuje mapowanie osi Triki zgodnie z bieżącą konfiguracją urządzenia.
  func applyAxisMapping(_ axisMapping: MotionAxisMapping) {
    grip = DartGripMapping.from(axisMapping: axisMapping)
  }

  /// Stosuje kalibrację tła i synchronizuje neutralne punkty dla celowania oraz rzutu.
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
    smoothedPosX = aim
    filteredLean = 0
  }

  private func rawLean(from input: GameInput) -> Double {
    grip.aimDelta(from: input.sensors, neutralX: aimNeutralTiltY, neutralY: 0).x
  }

  private func updateAim(input: GameInput, deltaTime: TimeInterval) {
    let raw = rawLean(from: input)
    filteredLean = filteredLean * (1 - leanFilterAlpha) + raw * leanFilterAlpha

    let dt = max(deltaTime, 1.0 / 120.0)

    guard abs(filteredLean) > leanHoldThreshold else {
      smoothedPosX = lockedAimX
      return
    }

    let sign: Double = filteredLean >= 0 ? 1 : -1
    let strength = min(1, (abs(filteredLean) - leanHoldThreshold) * 3.8)
    var step = sign * strength * maxAimStepPerFrame * lateralGain * 0.36 * dt * 60
    if invertLateral { step = -step }

    lockedAimX = MotionMath.clamp(lockedAimX + step)
    smoothedPosX = lockedAimX
  }

  /// Aktualizuje celowanie i wykrywa gest rzutu na podstawie wejścia z aktualnej klatki.
  ///
  /// - Parameters:
  ///   - input: Ujednolicona próbka wejścia z sensorów Triki.
  ///   - deltaTime: Czas trwania klatki symulacji.
  ///   - aimEnabled: Flaga włączająca/wyłączająca aktualizację celu.
  ///   - throwsEnabled: Flaga włączająca/wyłączająca emisję zdarzeń rzutu.
  /// - Returns: `ThrowEvent` tylko w klatce, w której wykryto poprawne zwolnienie.
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
        lateralPosX: smoothedPosX,
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
