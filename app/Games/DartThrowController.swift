import Foundation

/// Rzut od góry: podnieś rękę → gotowość → mocny ruch w dół (bez samostrzałów z szumu).
final class DartThrowController {
  /// Reprezentuje etapy gestu rzutu: od neutralnej postawy do finalnego zwolnienia.
  enum ThrowState: Equatable {
    case idle
    case pullingBack
    case ready
    case throwing

    var phoneLabel: String {
      switch self {
      case .idle: return "CELuj · nad tarczą"
      case .pullingBack: return "PODNIEŚ RĘKĘ"
      case .ready: return "RZUĆ W DÓŁ!"
      case .throwing: return "…"
      }
    }
  }

  private(set) var state: ThrowState = .idle
  private(set) var tiltVelocity: Double = 0
  private(set) var gyroForward: Double = 0
  private(set) var lastReleasePeakGyro: Double = 0
  private(set) var lastReleaseTiltVelocity: Double = 0

  private var lastTiltAxis: Double = 0
  private var cooldown: TimeInterval = 0
  private var throwConfirmFrames = 0

  private var idleNeutralTilt: Double = 0
  private var pullStartTilt: Double = 0
  private var readyTilt: Double = 0
  private var pullDecreasesAxis = true
  private var pullingBackElapsed: TimeInterval = 0
  private var readyElapsed: TimeInterval = 0
  private var readyHoldElapsed: TimeInterval = 0
  private var peakGyroWhileReady: Double = 0

  private let basePullTiltVelocity = -0.018
  private let baseThrowTiltVelocity = 0.034
  private let idleStability = 0.016

  /// Domyślne progi — nadpisywane przez `applyCalibration` z profilu gracza.
  private var minThrowGyroImpulse = 0.68
  private var strongThrowGyroImpulse = 0.92
  private var minPullDepth = 0.052
  private var minForwardDepth = 0.056
  private var minReadyHold: TimeInterval = 0.28
  private let shotCooldown: TimeInterval = 0.55
  private let maxReadyTime: TimeInterval = 3.0
  private let minPullingBackTime: TimeInterval = 0.16
  private var throwConfirmFramesRequired = 3
  private var gyroNoiseFloor = 0.14

  /// Informuje, czy gracz wszedł w fazę gotowości i może zwolnić rzut.
  var isPrimed: Bool { state == .ready }

  /// Informuje UI, czy celowanie powinno być spowolnione (podczas naciągu/gotowości).
  var isAimSlowed: Bool {
    state == .pullingBack || state == .ready
  }

  /// Progi z kalibracji — blisko kreatora, z podłogą (mniej fałszywych rzutów z drgań).
  func applyCalibration(pullDepth: Double, throwGyroPeak: Double) {
    let pull = min(0.11, max(0.036, pullDepth))
    let gyro = min(1.15, max(0.38, throwGyroPeak))
    minPullDepth = max(0.048, pull * 0.82)
    minForwardDepth = max(0.052, pull * 0.72)
    minThrowGyroImpulse = max(0.62, gyro * 0.78)
    strongThrowGyroImpulse = max(0.85, gyro * 1.02)
  }

  /// Ustawia domyślne progi kalibracji dla standardowego rzutu w darta.
  func applyDefaultCalibration() {
    applyCalibration(pullDepth: 0.052, throwGyroPeak: 0.78)
  }

  /// Bowling — łagodniejsze progi niż dart (wcześniejsze ustawienie).
  func applyBowlingCalibration() {
    minReadyHold = 0.28
    throwConfirmFramesRequired = 3
    gyroNoiseFloor = 0.14
    applyCalibration(pullDepth: 0.042, throwGyroPeak: 0.52)
  }

  /// Czyści stan automatu rzutu i synchronizuje neutralne położenie z bieżącym tiltem.
  func reset(tiltAxis: Double = 0) {
    state = .idle
    lastTiltAxis = tiltAxis
    cooldown = 0
    tiltVelocity = 0
    gyroForward = 0
    idleNeutralTilt = tiltAxis
    pullStartTilt = tiltAxis
    readyTilt = tiltAxis
    pullingBackElapsed = 0
    readyElapsed = 0
    readyHoldElapsed = 0
    peakGyroWhileReady = 0
    throwConfirmFrames = 0
  }

  @discardableResult
  /// Przetwarza próbkę ruchu i zwraca moc rzutu, gdy gest został poprawnie zakończony.
  ///
  /// - Parameters:
  ///   - tiltAxis: Oś pochylenia telefonu używana do detekcji naciągu i wypchnięcia.
  ///   - gyroForward: Sygnał żyroskopu w kierunku rzutu.
  ///   - deltaTime: Czas trwania aktualnej klatki.
  ///   - distanceFactor: Modyfikator czułości zależny od odległości/warunków gry.
  /// - Returns: Siłę rzutu gotową do przeliczenia na punkt trafienia lub `nil`.
  func update(
    tiltAxis: Double,
    gyroForward: Double,
    deltaTime: TimeInterval,
    distanceFactor: Double = 1.0
  ) -> Double? {
    let zone = min(1.35, max(0.85, distanceFactor))
    let dt = max(deltaTime, 1.0 / 120.0)

    if cooldown > 0 {
      cooldown = max(0, cooldown - dt)
      if state == .throwing, cooldown <= 0 {
        state = .idle
        idleNeutralTilt = tiltAxis
      }
      return nil
    }

    let tiltDelta = tiltAxis - lastTiltAxis
    lastTiltAxis = tiltAxis

    tiltVelocity = tiltDelta
    self.gyroForward = max(0, gyroForward - gyroNoiseFloor)

    switch state {
    case .idle:
      if abs(tiltVelocity) < idleStability {
        idleNeutralTilt = tiltAxis
      }
      beginPullbackIfNeeded(tiltAxis: tiltAxis, tiltDelta: tiltDelta, zone: zone)

    case .pullingBack:
      pullingBackElapsed += dt
      let depth = pullDepthFromNeutral(tiltAxis: tiltAxis)
      if depth >= minPullDepth / zone, pullingBackElapsed >= minPullingBackTime {
        state = .ready
        readyTilt = tiltAxis
        readyElapsed = 0
        readyHoldElapsed = 0
        peakGyroWhileReady = 0
      } else if pullingBackElapsed > 2.5 {
        state = .idle
      }

    case .ready:
      readyElapsed += dt
      peakGyroWhileReady = max(peakGyroWhileReady, gyroForward, self.gyroForward)
      if pullDepthFromNeutral(tiltAxis: tiltAxis) >= minPullDepth * 0.38 / zone {
        readyHoldElapsed += dt
      } else {
        readyHoldElapsed = 0
      }

      if readyHoldElapsed >= minReadyHold,
         shouldReleaseThrow(
          tiltAxis: tiltAxis,
          tiltDelta: tiltDelta,
          zone: zone,
          peakGyro: peakGyroWhileReady
         ) {
        throwConfirmFrames += 1
        if throwConfirmFrames >= throwConfirmFramesRequired {
          state = .throwing
          cooldown = shotCooldown
          throwConfirmFrames = 0
          let peak = max(peakGyroWhileReady, self.gyroForward, abs(tiltVelocity) * 5)
          lastReleasePeakGyro = peak
          lastReleaseTiltVelocity = tiltVelocity
          return throwPower(from: peak, zone: zone)
        }
      } else {
        throwConfirmFrames = 0
      }

      if readyElapsed > maxReadyTime {
        state = .idle
      } else if pullDepthFromNeutral(tiltAxis: tiltAxis) < minPullDepth * 0.15 / zone, readyElapsed > 0.5 {
        state = .idle
      }

    case .throwing:
      break
    }

    return nil
  }

  /// Rzut przy mocnym machnięciu (żyro) + ruch w dół od pozycji „ready”.
  private func shouldReleaseThrow(
    tiltAxis: Double,
    tiltDelta: Double,
    zone: Double,
    peakGyro: Double
  ) -> Bool {
    let forward = forwardDepth(tiltAxis: tiltAxis)
    let gyro = max(peakGyro, self.gyroForward)
    let tiltPush = tiltVelocity > baseThrowTiltVelocity / zone
    let impulse = forwardImpulse(delta: tiltDelta, zone: zone)
    let minForward = minForwardDepth / zone

    guard gyro >= minThrowGyroImpulse / zone else { return false }
    guard forward >= minForward * 0.85 else { return false }
    guard impulse || tiltPush else { return false }

    if gyro >= strongThrowGyroImpulse / zone {
      return forward >= minForward * 0.55
    }

    return forward >= minForward
  }

  /// Start cofania od pozycji neutralnej (tiltAxis ≈ 0 względem profilu).
  private func beginPullbackIfNeeded(tiltAxis: Double, tiltDelta: Double, zone: Double) {
    let pullSpeed = abs(basePullTiltVelocity) * zone
    let dist = abs(tiltAxis - idleNeutralTilt)
    let minDist = max(minPullDepth * 0.5 / zone, pullSpeed * 0.55)
    let moving = abs(tiltVelocity) >= pullSpeed * 0.95
      || abs(tiltDelta) >= pullSpeed * 0.95

    guard moving, dist >= minDist else { return }

    pullDecreasesAxis = (tiltAxis - idleNeutralTilt) < 0
    if abs(tiltVelocity) >= pullSpeed * 0.95 {
      pullDecreasesAxis = tiltVelocity < 0
    } else if abs(tiltDelta) >= pullSpeed * 0.95 {
      pullDecreasesAxis = tiltDelta < 0
    }

    state = .pullingBack
    pullStartTilt = idleNeutralTilt
    pullingBackElapsed = 0
    readyHoldElapsed = 0
    peakGyroWhileReady = 0
    throwConfirmFrames = 0
  }

  private func pullDepthFromNeutral(tiltAxis: Double) -> Double {
    abs(tiltAxis - idleNeutralTilt)
  }

  private func pullDepth(tiltAxis: Double) -> Double {
    pullDecreasesAxis ? max(0, pullStartTilt - tiltAxis) : max(0, tiltAxis - pullStartTilt)
  }

  private func forwardDepth(tiltAxis: Double) -> Double {
    pullDecreasesAxis ? tiltAxis - readyTilt : readyTilt - tiltAxis
  }

  private func forwardImpulse(delta: Double, zone: Double) -> Bool {
    let threshold = (baseThrowTiltVelocity * 0.72) / zone
    return pullDecreasesAxis ? delta > threshold : delta < -threshold
  }

  private func throwPower(from peak: Double, zone: Double) -> Double {
    let ref = minThrowGyroImpulse / zone
    let scaled = peak / max(0.001, ref)
    return min(20, max(4, scaled * 9))
  }
}
