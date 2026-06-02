import SwiftUI
import UIKit

/// Blokada orientacji: menu + gra w pionie (naturalny chwyt telefonu).
final class AppDelegate: NSObject, UIApplicationDelegate {
/// Przechowuje wartosc `orientationLock`.
  static var orientationLock: UIInterfaceOrientationMask = .portrait

/// Wykonuje operacje `application`.
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    if let window, window.windowScene?.screen != UIScreen.main {
      return [.landscapeLeft, .landscapeRight]
    }
    return Self.orientationLock
  }
}

/// Reprezentuje typ `AppOrientation`.
enum AppOrientation {
/// Wykonuje operacje `lockPortrait`.
  static func lockPortrait() {
    AppDelegate.orientationLock = .portrait
    requestUpdate()
  }

/// Wykonuje operacje `unlock`.
  static func unlock() {
    AppDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
    requestUpdate()
  }

  private static func requestUpdate() {
    // Odłóż do następnej pętli runloop — unika crashy przy push nawigacji (Graj → gra).
    DispatchQueue.main.async {
      guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
      let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: AppDelegate.orientationLock)
      scene.requestGeometryUpdate(prefs) { _ in }
      for window in scene.windows {
        window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      }
    }
  }
}

private struct PhonePortraitGameModifier: ViewModifier {
/// Wykonuje operacje `body`.
  func body(content: Content) -> some View {
    content
      .toolbar(.hidden, for: .navigationBar)
      .statusBarHidden(true)
      .persistentSystemOverlays(.hidden)
      .onAppear { AppOrientation.lockPortrait() }
      .onDisappear { AppOrientation.unlock() }
  }
}

/// Rozszerza istniejacy typ o dodatkowe zachowanie.
extension View {
  /// Pełny ekran gry — telefon w pionie.
  func phonePortraitGame() -> some View {
    modifier(PhonePortraitGameModifier())
  }
}
