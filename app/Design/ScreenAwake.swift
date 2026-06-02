import UIKit

/// Blokuje wygaszanie ekranu podczas gry (referencje — zagnieżdżone sesje).
@MainActor
/// Reprezentuje typ `ScreenAwake`.
enum ScreenAwake {
  private static var holdCount = 0
  private static var didInstallLifecycleObserver = false

/// Wykonuje operacje `push`.
  static func push() {
    installLifecycleObserverIfNeeded()
    holdCount += 1
    apply()
  }

  private static func installLifecycleObserverIfNeeded() {
    guard !didInstallLifecycleObserver else { return }
    didInstallLifecycleObserver = true
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { _ in
      Task { @MainActor in apply() }
    }
  }

/// Wykonuje operacje `pop`.
  static func pop() {
    guard holdCount > 0 else { return }
    holdCount -= 1
    apply()
  }

/// Wykonuje operacje `releaseAll`.
  static func releaseAll() {
    holdCount = 0
    apply()
  }

  /// Stosuje ustawienie użytkownika do `isIdleTimerDisabled` (np. po przełączeniu toggle w menu).
  static func apply() {
    let keepOn = holdCount > 0 && ArcadeSettings.keepScreenOnDuringPlay
    UIApplication.shared.isIdleTimerDisabled = keepOn
  }
}
