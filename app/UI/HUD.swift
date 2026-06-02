import SwiftUI
import VeltoKit

/// Wspólne elementy HUD w grach (sterowanie, połączenie Triki).
enum ArcadeHUD {
  /// Buduje plakietkę stanu połączenia Triki dla ekranów gry.
  ///
  /// - Parameters:
  ///   - connected: Czy telefon jest połączony z sesją wejścia.
  ///   - receiving: Czy napływają aktualne próbki ruchu.
  /// - Returns: Widok z kolorem statusu i etykietą połączenia.
  static func connectionBadge(connected: Bool, receiving: Bool) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(connected ? (receiving ? Color.green : Color.orange) : Color.red)
        .frame(width: 8, height: 8)
      Text(connected ? (receiving ? "TRIKI LIVE" : "POŁĄCZONO") : "BRAK TRIKI")
        .font(.system(size: 9, weight: .bold, design: .monospaced))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.black.opacity(0.55))
    .clipShape(Capsule())
  }

  /// Buduje pojedynczy wiersz diagnostyczny HUD (etykieta + wartość).
  ///
  /// - Parameters:
  ///   - label: Nazwa metryki.
  ///   - value: Sformatowana wartość metryki.
  static func motionRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.55))
      Spacer()
      Text(value)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)
    }
  }
}
