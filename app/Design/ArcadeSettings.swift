import Foundation

/// Reprezentuje typ `ArcadeSettings`.
enum ArcadeSettings {
/// Przechowuje wartosc `keepScreenOnDuringPlayKey`.
  static let keepScreenOnDuringPlayKey = "arcade.keepScreenOnDuringPlay"
/// Przechowuje wartosc `backgroundMusicEnabledKey`.
  static let backgroundMusicEnabledKey = "arcade.backgroundMusicEnabled"

/// Przechowuje wartosc `backgroundMusicEnabled`.
  static var backgroundMusicEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: backgroundMusicEnabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: backgroundMusicEnabledKey) }
  }

/// Przechowuje wartosc `keepScreenOnDuringPlay`.
  static var keepScreenOnDuringPlay: Bool {
    get {
      if UserDefaults.standard.object(forKey: keepScreenOnDuringPlayKey) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: keepScreenOnDuringPlayKey)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: keepScreenOnDuringPlayKey)
      DispatchQueue.main.async {
        ScreenAwake.apply()
      }
    }
  }
}
