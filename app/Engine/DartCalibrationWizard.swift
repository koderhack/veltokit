import Combine
import Foundation
import VeltoKit

/// Reprezentuje typ `DartCalibrationStep`.
enum DartCalibrationStep: String, Equatable {
  case neutral
  case pullBack
  case pushForward
  case done

/// Przechowuje wartosc `title`.
  var title: String {
    switch self {
    case .neutral: return "POZYCJA NEUTRALNA"
    case .pullBack: return "PODNIEŚ RĘKĘ"
    case .pushForward: return "RZUT W DÓŁ"
    case .done: return "GOTOWE"
    }
  }

/// Przechowuje wartosc `tvDetail`.
  var tvDetail: String {
    switch self {
    case .neutral:
      return "Triki nad tarczą · skierowany w dół · trzymaj spokojnie ok. 6–7 s"
    case .pullBack:
      return "Podnieś rękę nad cel i zatrzymaj — ok. 5–6 s"
    case .pushForward:
      return "Jeden mocny, wyraźny ruch w dół — jak rzut lotką"
    case .done:
      return "Zapisano cel · odległość · podniesienie · moc rzutu w dół"
    }
  }

/// Przechowuje wartosc `phoneHint`.
  var phoneHint: String {
    switch self {
    case .neutral:
      return "Trzymaj spokojnie kilka sekund · hold lub „Dalej” gdy gotowe"
    case .pullBack:
      return "Unieś rękę nad tarczą i zatrzymaj — nie spiesz się"
    case .pushForward:
      return "Rzuć w dół — szybki ruch nad planszą"
    case .done:
      return "Możesz zacząć grę"
    }
  }
}

@MainActor
/// Reprezentuje typ `DartCalibrationWizard`.
final class DartCalibrationWizard: ObservableObject {
  /// Czas trzymania pozycji neutralnej (s).
  private static let neutralHoldDuration: TimeInterval = 6.5
  /// Ruch mniejszy niż ten próg = „spokojnie” w neutralu.
  private static let neutralMotionThreshold = 0.14
  /// Minimalny czas w kroku cofania (s) — żeby zdążyć powoli.
  private static let pullBackMinDuration: TimeInterval = 5.0
  /// Głębokość cofnięcia (tilt) do pełnego paska.
  private static let pullBackDepthTarget = 0.048
  /// Trzymanie w cofniętej pozycji po wypełnieniu paska (s).
  private static let pullBackHoldAtFull: TimeInterval = 2.8
  /// Zanim zaliczymy rzut do przodu — czas na przygotowanie (s).
  private static let pushForwardMinDuration: TimeInterval = 2.5

  @Published private(set) var step: DartCalibrationStep = .neutral
  @Published private(set) var progress: Double = 0
  @Published private(set) var playerIndex = 0
  @Published private(set) var isComplete = false

/// Przechowuje wartosc `playerCount`.
  let playerCount: Int
  private unowned let session: DartSession

/// Wykonuje operacje `playerDisplayName`.
  func playerDisplayName(for index: Int) -> String {
    session.name(at: index)
  }

  private var grip = DartGripMapping.overhead
  private var neutralSamples = DartPlayerProfile(
    referenceEnergy: 0, aimNeutralX: 0, aimNeutralY: 0,
    throwNeutralTilt: 0, gyroBaselineX: 0, gyroBaselineY: 0, gyroBaselineZ: 0
  )
  private var pullTiltPeak: Double = 0
  private var stableNeutralTime: TimeInterval = 0
  private var pullHoldTime: TimeInterval = 0
  private var stepElapsed: TimeInterval = 0
  private var forwardDetected = false
  private var calibrationGyroPeak: Double = 0

/// Inicjalizuje nowa instancje.
  init(session: DartSession) {
    self.session = session
    self.playerCount = session.playerCount
  }

/// Wykonuje operacje `applyGrip`.
  func applyGrip(from axisMapping: MotionAxisMapping) {
    grip = DartGripMapping.from(axisMapping: axisMapping)
  }

/// Wykonuje operacje `resetForPlayer`.
  func resetForPlayer(_ index: Int) {
    playerIndex = index
    stableNeutralTime = 0
    forwardDetected = false
    isComplete = false
    beginStep(.neutral)
  }

  private func beginStep(_ newStep: DartCalibrationStep) {
    step = newStep
    progress = 0
    stepElapsed = 0
    pullHoldTime = 0
    if newStep == .pullBack {
      pullTiltPeak = 0
    }
    if newStep == .pushForward {
      forwardDetected = false
      calibrationGyroPeak = 0
    }
  }

  private func capturePullCalibration() {
    neutralSamples.calibratedPullDepth = max(pullTiltPeak, 0.028)
  }

/// Wykonuje operacje `confirmCurrentStep`.
  func confirmCurrentStep(sensors: TrikiSensors) {
    switch step {
    case .neutral:
      captureNeutral(sensors)
      beginStep(.pullBack)
    case .pushForward where forwardDetected:
      finishPlayer(sensors)
    default:
      break
    }
  }

/// Wykonuje operacje `tick`.
  func tick(sensors: TrikiSensors, deltaTime: TimeInterval) {
    guard !isComplete else { return }

    switch step {
    case .neutral:
      tickNeutral(sensors: sensors, deltaTime: deltaTime)
    case .pullBack:
      tickPullBack(sensors: sensors, deltaTime: deltaTime)
    case .pushForward:
      tickPushForward(sensors: sensors, deltaTime: deltaTime)
    case .done:
      break
    }
  }

  private func tickNeutral(sensors: TrikiSensors, deltaTime: TimeInterval) {
    let motion = motionEnergy(sensors)
    if motion < Self.neutralMotionThreshold {
      stableNeutralTime += deltaTime
    } else {
      stableNeutralTime = max(0, stableNeutralTime - deltaTime * 0.85)
    }
    progress = min(1, stableNeutralTime / Self.neutralHoldDuration)
    if stableNeutralTime >= Self.neutralHoldDuration {
      captureNeutral(sensors)
      beginStep(.pullBack)
      ArcadeAudio.calibrationStep()
    }
  }

  private func tickPullBack(sensors: TrikiSensors, deltaTime: TimeInterval) {
    stepElapsed += deltaTime
    let axis = grip.throwTiltAxis(from: sensors, neutral: neutralSamples.throwNeutralTilt)
    pullTiltPeak = max(pullTiltPeak, abs(axis))

    let depthProgress = min(1, pullTiltPeak / Self.pullBackDepthTarget)
    let timeProgress = min(1, stepElapsed / Self.pullBackMinDuration)
    progress = min(depthProgress, timeProgress)

    let depthReady = depthProgress >= 1
    let timeReady = timeProgress >= 1
    if depthReady && timeReady {
      pullHoldTime += deltaTime
      progress = min(1, pullHoldTime / Self.pullBackHoldAtFull)
      if pullHoldTime >= Self.pullBackHoldAtFull {
        capturePullCalibration()
        beginStep(.pushForward)
        ArcadeAudio.calibrationStep()
      }
    } else {
      pullHoldTime = 0
    }
  }

  private func tickPushForward(sensors: TrikiSensors, deltaTime: TimeInterval) {
    stepElapsed += deltaTime

    let prepProgress = min(1, stepElapsed / Self.pushForwardMinDuration)
    if stepElapsed < Self.pushForwardMinDuration {
      progress = prepProgress * 0.25
      return
    }

    var bx = neutralSamples.gyroBaselineX
    var by = neutralSamples.gyroBaselineY
    var bz = neutralSamples.gyroBaselineZ
    let impulse = grip.throwGyroImpulse(from: sensors, baselineX: &bx, baselineY: &by, baselineZ: &bz)
    calibrationGyroPeak = max(calibrationGyroPeak, impulse)
    let forwardTilt = abs(grip.throwTiltAxis(from: sensors, neutral: neutralSamples.throwNeutralTilt))
    let tiltForward = forwardTilt
    let throwProgress = min(1, max(impulse / 0.55, tiltForward / 0.05))
    progress = 0.25 + throwProgress * 0.75

    let throwThreshold = max(calibrationGyroPeak * 0.88, 0.42)
    if impulse >= throwThreshold || tiltForward >= 0.04 {
      forwardDetected = true
      progress = 1
      finishPlayer(sensors)
    }
  }

  private func captureNeutral(_ sensors: TrikiSensors) {
    let n = grip.calibrateNeutrals(from: sensors)
    neutralSamples.aimNeutralX = n.aimX
    neutralSamples.aimNeutralY = n.aimY
    neutralSamples.throwNeutralTilt = n.throwTilt
    neutralSamples.gyroBaselineX = sensors.gyroX
    neutralSamples.gyroBaselineY = sensors.gyroY
    neutralSamples.gyroBaselineZ = sensors.gyroZ
    neutralSamples.referenceEnergy = motionEnergy(sensors)
  }

  private func finishPlayer(_ sensors: TrikiSensors) {
    var bx = neutralSamples.gyroBaselineX
    var by = neutralSamples.gyroBaselineY
    var bz = neutralSamples.gyroBaselineZ
    let impulse = grip.throwGyroImpulse(from: sensors, baselineX: &bx, baselineY: &by, baselineZ: &bz)
    calibrationGyroPeak = max(calibrationGyroPeak, impulse)
    neutralSamples.gyroBaselineX = bx
    neutralSamples.gyroBaselineY = by
    neutralSamples.gyroBaselineZ = bz
    if calibrationGyroPeak > 0.2 {
      neutralSamples.calibratedThrowGyroPeak = calibrationGyroPeak
    }
    if pullTiltPeak > 0.02 {
      neutralSamples.calibratedPullDepth = max(pullTiltPeak, neutralSamples.calibratedPullDepth)
    }
    DartPlayerProfileStore.save(neutralSamples, for: playerIndex)
    ArcadeAudio.calibrationStep()

    if playerIndex + 1 < playerCount {
      resetForPlayer(playerIndex + 1)
      return
    }

    step = .done
    progress = 1
    isComplete = true
    ArcadeAudio.calibrationDone()
  }

  private func motionEnergy(_ sensors: TrikiSensors) -> Double {
    let g2 = sensors.gyroX * sensors.gyroX + sensors.gyroY * sensors.gyroY + sensors.gyroZ * sensors.gyroZ
    let t2 = sensors.tiltX * sensors.tiltX + sensors.tiltY * sensors.tiltY
    return min(1, sqrt(g2) * 0.85 + sqrt(t2) * 0.35)
  }
}
