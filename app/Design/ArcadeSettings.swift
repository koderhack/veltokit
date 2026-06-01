import Foundation

enum ArcadeSettings {
  static let keepScreenOnDuringPlayKey = "arcade.keepScreenOnDuringPlay"
  static let backgroundMusicEnabledKey = "arcade.backgroundMusicEnabled"

  static var backgroundMusicEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: backgroundMusicEnabledKey) }
    set { UserDefaults.standard.set(newValue, forKey: backgroundMusicEnabledKey) }
  }

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
