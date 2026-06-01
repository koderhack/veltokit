import Foundation
import VeltoKit

/// Szacuje dystans od ekranu po „energii” ruchu żyro (kalibracja = Twoja wygodna strefa).
final class DartPlayZone {
  /// Przekazanie kalibracji z ekranu „GRAJ”.
  static var sessionReferenceEnergy: Double?

  /// Odległość fizyczna (jak stoisz z Triki w dłoni) — nie mierzy ekranu telefonu ani TV.
  static let distanceExplanation =
    "Stoisz przed ekranem z Triki w dłoni (telefon lub TV). " +
    "Pasek mierzy ruch kontrolera, nie odległość od wyświetlacza."

  enum Band: String, Equatable {
    case unknown = "—"
    case close = "BLISKO"
    case good = "OK"
    case far = "DALEKO"

    var hint: String {
      switch self {
      case .unknown: return "Kalibruj przy starcie gry"
      case .close: return "Trochę za blisko — odsuń się"
      case .good: return "Dobra odległość"
      case .far: return "Za daleko — podejdź bliżej"
      }
    }
  }

  private(set) var referenceEnergy: Double = 0
  private(set) var liveEnergy: Double = 0
  private(set) var band: Band = .unknown
  private(set) var level: Int = 0
  private(set) var distanceFactor: Double = 1.0
  private(set) var isCalibrated = false

  /// Do UI przed zapisem referencji — szacunek z energii ruchu.
  var displayBand: Band {
    isCalibrated ? band : Self.absoluteBand(for: liveEnergy)
  }

  var displayLevel: Int {
    isCalibrated ? level : Self.absoluteLevel(for: liveEnergy)
  }

  private var calibrated = false

  func applySessionCalibration() {
    guard let energy = Self.sessionReferenceEnergy, energy > 0.008 else { return }
    referenceEnergy = energy
    calibrated = true
    isCalibrated = true
  }

  func stashForSession() {
    guard referenceEnergy > 0.008 else { return }
    Self.sessionReferenceEnergy = referenceEnergy
  }

  func applyProfile(_ profile: DartPlayerProfile) {
    referenceEnergy = profile.referenceEnergy
    calibrated = true
    isCalibrated = true
    band = .good
    level = 3
    distanceFactor = 1.0
  }

  func reset() {
    referenceEnergy = 0
    liveEnergy = 0
    band = .unknown
    level = 0
    distanceFactor = 1.0
    calibrated = false
    isCalibrated = false
  }

  /// Zapisz neutralną odległość (przycisk GRAJ / kalibracja).
  func calibrate(with sensors: TrikiSensors) {
    let energy = motionEnergy(sensors)
    guard energy > 0.008 else { return }
    referenceEnergy = energy
    calibrated = true
    isCalibrated = true
    refresh(sensors: sensors)
  }

  func update(sensors: TrikiSensors) {
    liveEnergy = motionEnergy(sensors)
    refresh(sensors: sensors)
  }

  private func refresh(sensors: TrikiSensors) {
    _ = sensors
    guard calibrated, referenceEnergy > 0.008 else {
      band = .unknown
      level = 0
      distanceFactor = 1.0
      return
    }

    let ratio = liveEnergy / referenceEnergy
    switch ratio {
    case ..<0.55:
      band = .far
      distanceFactor = 1.45
      level = 1
    case ..<0.82:
      band = .far
      distanceFactor = 1.22
      level = 2
    case ..<1.18:
      band = .good
      distanceFactor = 1.0
      level = 3
    case ..<1.55:
      band = .close
      distanceFactor = 0.88
      level = 4
    default:
      band = .close
      distanceFactor = 0.75
      level = 5
    }
  }

  private static func absoluteBand(for energy: Double) -> Band {
    switch energy {
    case ..<0.08: return .unknown
    case ..<0.14: return .far
    case ..<0.30: return .good
    default: return .close
    }
  }

  private static func absoluteLevel(for energy: Double) -> Int {
    switch energy {
    case ..<0.08: return 0
    case ..<0.14: return 1
    case ..<0.20: return 2
    case ..<0.26: return 3
    case ..<0.32: return 4
    default: return 5
    }
  }

  private func motionEnergy(_ sensors: TrikiSensors) -> Double {
    let g2 = sensors.gyroX * sensors.gyroX
      + sensors.gyroY * sensors.gyroY
      + sensors.gyroZ * sensors.gyroZ
    let t2 = sensors.tiltX * sensors.tiltX + sensors.tiltY * sensors.tiltY
    return min(1, sqrt(g2) * 0.85 + sqrt(t2) * 0.35)
  }
}
