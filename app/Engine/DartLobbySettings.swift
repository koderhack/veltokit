import Foundation
import VeltoKit

/// Trwałe ustawienia lobby Dart (UserDefaults).
enum DartLobbySettings {
/// Przechowuje wartosc `invertXKey`.
  static let invertXKey = "dart.lobby.invertX"
/// Przechowuje wartosc `invertYKey`.
  static let invertYKey = "dart.lobby.invertY"
/// Przechowuje wartosc `modeKey`.
  static let modeKey = "dart.lobby.mode"
/// Przechowuje wartosc `playerCountKey`.
  static let playerCountKey = "dart.lobby.playerCount"
/// Przechowuje wartosc `playerNamesKey`.
  static let playerNamesKey = "dart.lobby.playerNames"
/// Przechowuje wartosc `player1NameKey`.
  static let player1NameKey = "dart.lobby.player1"
/// Przechowuje wartosc `player2NameKey`.
  static let player2NameKey = "dart.lobby.player2"

/// Wykonuje operacje `applyToAxisMapping`.
  static func applyToAxisMapping(_ mapping: inout MotionAxisMapping) {
    let d = UserDefaults.standard
    if d.object(forKey: invertXKey) != nil {
      mapping.invertX = d.bool(forKey: invertXKey)
    }
    if d.object(forKey: invertYKey) != nil {
      mapping.invertY = d.bool(forKey: invertYKey)
    }
  }

/// Wykonuje operacje `saveAxisMapping`.
  static func saveAxisMapping(_ mapping: MotionAxisMapping) {
    let d = UserDefaults.standard
    d.set(mapping.invertX, forKey: invertXKey)
    d.set(mapping.invertY, forKey: invertYKey)
  }

/// Wykonuje operacje `loadMode`.
  static func loadMode() -> DartPlayMode? {
    guard let raw = UserDefaults.standard.string(forKey: modeKey) else { return nil }
    return DartPlayMode(rawValue: raw)
  }

/// Wykonuje operacje `loadPlayerCount`.
  static func loadPlayerCount() -> Int? {
    let d = UserDefaults.standard
    guard d.object(forKey: playerCountKey) != nil else { return nil }
    return DartPlayers.clampCount(d.integer(forKey: playerCountKey))
  }

/// Wykonuje operacje `savePlayerCount`.
  static func savePlayerCount(_ count: Int) {
    UserDefaults.standard.set(DartPlayers.clampCount(count), forKey: playerCountKey)
  }

/// Wykonuje operacje `loadPlayerNames`.
  static func loadPlayerNames() -> [String]? {
    guard let data = UserDefaults.standard.data(forKey: playerNamesKey),
          let names = try? JSONDecoder().decode([String].self, from: data),
          !names.isEmpty
    else { return nil }
    return names
  }

/// Wykonuje operacje `savePlayerNames`.
  static func savePlayerNames(_ names: [String]) {
    if let data = try? JSONEncoder().encode(names) {
      UserDefaults.standard.set(data, forKey: playerNamesKey)
    }
  }

/// Wykonuje operacje `loadPlayerNamesLegacy`.
  static func loadPlayerNamesLegacy() -> (String?, String?) {
    let d = UserDefaults.standard
    return (d.string(forKey: player1NameKey), d.string(forKey: player2NameKey))
  }
}
