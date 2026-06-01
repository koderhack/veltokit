import Foundation
import VeltoKit

/// Trwałe ustawienia lobby Dart (UserDefaults).
enum DartLobbySettings {
  static let invertXKey = "dart.lobby.invertX"
  static let invertYKey = "dart.lobby.invertY"
  static let modeKey = "dart.lobby.mode"
  static let playerCountKey = "dart.lobby.playerCount"
  static let playerNamesKey = "dart.lobby.playerNames"
  static let player1NameKey = "dart.lobby.player1"
  static let player2NameKey = "dart.lobby.player2"

  static func applyToAxisMapping(_ mapping: inout MotionAxisMapping) {
    let d = UserDefaults.standard
    if d.object(forKey: invertXKey) != nil {
      mapping.invertX = d.bool(forKey: invertXKey)
    }
    if d.object(forKey: invertYKey) != nil {
      mapping.invertY = d.bool(forKey: invertYKey)
    }
  }

  static func saveAxisMapping(_ mapping: MotionAxisMapping) {
    let d = UserDefaults.standard
    d.set(mapping.invertX, forKey: invertXKey)
    d.set(mapping.invertY, forKey: invertYKey)
  }

  static func loadMode() -> DartPlayMode? {
    guard let raw = UserDefaults.standard.string(forKey: modeKey) else { return nil }
    return DartPlayMode(rawValue: raw)
  }

  static func loadPlayerCount() -> Int? {
    let d = UserDefaults.standard
    guard d.object(forKey: playerCountKey) != nil else { return nil }
    return DartPlayers.clampCount(d.integer(forKey: playerCountKey))
  }

  static func savePlayerCount(_ count: Int) {
    UserDefaults.standard.set(DartPlayers.clampCount(count), forKey: playerCountKey)
  }

  static func loadPlayerNames() -> [String]? {
    guard let data = UserDefaults.standard.data(forKey: playerNamesKey),
          let names = try? JSONDecoder().decode([String].self, from: data),
          !names.isEmpty
    else { return nil }
    return names
  }

  static func savePlayerNames(_ names: [String]) {
    if let data = try? JSONEncoder().encode(names) {
      UserDefaults.standard.set(data, forKey: playerNamesKey)
    }
  }

  static func loadPlayerNamesLegacy() -> (String?, String?) {
    let d = UserDefaults.standard
    return (d.string(forKey: player1NameKey), d.string(forKey: player2NameKey))
  }
}
