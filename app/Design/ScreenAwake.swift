import UIKit

/// Blokuje wygaszanie ekranu podczas gry (referencje — zagnieżdżone sesje).
@MainActor
enum ScreenAwake {
  private static var holdCount = 0
  private static var didInstallLifecycleObserver = false

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

  static func pop() {
    guard holdCount > 0 else { return }
    holdCount -= 1
    apply()
  }

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
