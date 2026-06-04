import SwiftUI
import VeltoKit

enum ArcadeHUD {
  static func connectionBadge(connected: Bool, receiving: Bool) -> some View {
    connectionBadge(connected: connected, receiving: receiving, bleMode: .unknown)
  }

  static func connectionBadge(
    connected: Bool,
    receiving: Bool,
    bleMode: TrikiBLEMode
  ) -> some View {
    let (dot, label): (Color, String) = {
      guard connected else { return (.red, "BRAK TRIKI") }
      switch bleMode {
      case .fast where receiving:
        return (.green, "TRIKI · SZYBKI")
      case .normal where receiving:
        return (NeonTheme.neonCyan, "TRIKI · NORMAL")
      case .lowPower:
        return (NeonTheme.neonOrange, receiving ? "TRIKI · CZUWANIE" : "TRIKI · OSZCZ.")
      case .fast, .normal:
        return (.orange, "POŁĄCZONO")
      case .unknown:
        return (receiving ? .green : .orange, receiving ? "TRIKI LIVE" : "POŁĄCZONO")
      }
    }()

    return HStack(spacing: 6) {
      Circle()
        .fill(dot)
        .frame(width: 8, height: 8)
      Text(label)
        .font(.system(size: 9, weight: .bold, design: .monospaced))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.black.opacity(0.55))
    .clipShape(Capsule())
  }

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
