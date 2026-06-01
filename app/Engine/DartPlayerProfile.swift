import Foundation
import VeltoKit

/// Zapis kalibracji jednego gracza (neutral · podniesienie · rzut w dół).
struct DartPlayerProfile: Equatable, Codable {
  var referenceEnergy: Double
  var aimNeutralX: Double
  var aimNeutralY: Double
  var throwNeutralTilt: Double
  var gyroBaselineX: Double
  var gyroBaselineY: Double
  var gyroBaselineZ: Double
  /// Jak głęboko cofnąłeś rękę w kroku 2 (tilt względem neutralu).
  var calibratedPullDepth: Double
  /// Szczyt impulsu żyro przy machnięciu w kroku 3 — próg rzutu w grze.
  var calibratedThrowGyroPeak: Double

  init(
    referenceEnergy: Double,
    aimNeutralX: Double,
    aimNeutralY: Double,
    throwNeutralTilt: Double,
    gyroBaselineX: Double,
    gyroBaselineY: Double,
    gyroBaselineZ: Double = 0,
    calibratedPullDepth: Double = 0.042,
    calibratedThrowGyroPeak: Double = 0.78
  ) {
    self.referenceEnergy = referenceEnergy
    self.aimNeutralX = aimNeutralX
    self.aimNeutralY = aimNeutralY
    self.throwNeutralTilt = throwNeutralTilt
    self.gyroBaselineX = gyroBaselineX
    self.gyroBaselineY = gyroBaselineY
    self.gyroBaselineZ = gyroBaselineZ
    self.calibratedPullDepth = calibratedPullDepth
    self.calibratedThrowGyroPeak = calibratedThrowGyroPeak
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    referenceEnergy = try c.decode(Double.self, forKey: .referenceEnergy)
    aimNeutralX = try c.decode(Double.self, forKey: .aimNeutralX)
    aimNeutralY = try c.decode(Double.self, forKey: .aimNeutralY)
    throwNeutralTilt = try c.decode(Double.self, forKey: .throwNeutralTilt)
    gyroBaselineX = try c.decode(Double.self, forKey: .gyroBaselineX)
    gyroBaselineY = try c.decode(Double.self, forKey: .gyroBaselineY)
    gyroBaselineZ = try c.decodeIfPresent(Double.self, forKey: .gyroBaselineZ) ?? 0
    calibratedPullDepth = try c.decodeIfPresent(Double.self, forKey: .calibratedPullDepth) ?? 0.042
    calibratedThrowGyroPeak = try c.decodeIfPresent(Double.self, forKey: .calibratedThrowGyroPeak) ?? 0.78
  }

  var isComplete: Bool {
    referenceEnergy > 0.008 && calibratedPullDepth > 0.02 && calibratedThrowGyroPeak > 0.2
  }
}

enum DartPlayerProfileStore {
  private static let p1Key = "dart.profile.player1"
  private static let p2Key = "dart.profile.player2"

  static var player1: DartPlayerProfile? {
    get { profile(for: 0) }
    set { if let newValue { save(newValue, for: 0) } else { save(nil, key: key(for: 0)) } }
  }

  static var player2: DartPlayerProfile? {
    get { profile(for: 1) }
    set { if let newValue { save(newValue, for: 1) } else { save(nil, key: key(for: 1)) } }
  }

  static func profile(for playerIndex: Int) -> DartPlayerProfile? {
    guard playerIndex >= 0, playerIndex < DartPlayers.maxCount else { return nil }
    if playerIndex == 0, let p = load(key: p1Key) { return p }
    if playerIndex == 1, let p = load(key: p2Key) { return p }
    return load(key: key(for: playerIndex))
  }

  static func save(_ profile: DartPlayerProfile, for playerIndex: Int) {
    guard playerIndex >= 0, playerIndex < DartPlayers.maxCount else { return }
    save(profile, key: key(for: playerIndex))
    if playerIndex == 0 {
      DartPlayZone.sessionReferenceEnergy = profile.referenceEnergy
    }
  }

  private static func key(for playerIndex: Int) -> String {
    switch playerIndex {
    case 0: return p1Key
    case 1: return p2Key
    default: return "dart.profile.player.\(playerIndex)"
    }
  }

  private static func load(key: String) -> DartPlayerProfile? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(DartPlayerProfile.self, from: data)
  }

  private static func save(_ profile: DartPlayerProfile?, key: String) {
    guard let profile else {
      UserDefaults.standard.removeObject(forKey: key)
      return
    }
    if let data = try? JSONEncoder().encode(profile) {
      UserDefaults.standard.set(data, forKey: key)
    }
  }
}
