import SwiftUI

/// Reprezentuje typ `NeonTheme`.
enum NeonTheme {
/// Przechowuje wartosc `bg`.
  static let bg = Color(red: 0.03, green: 0.03, blue: 0.06)
/// Przechowuje wartosc `panel`.
  static let panel = Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.9)

/// Przechowuje wartosc `neonCyan`.
  static let neonCyan = Color(red: 0.25, green: 0.92, blue: 1.00)
/// Przechowuje wartosc `neonMagenta`.
  static let neonMagenta = Color(red: 1.00, green: 0.22, blue: 0.80)
/// Przechowuje wartosc `neonGreen`.
  static let neonGreen = Color(red: 0.22, green: 1.00, blue: 0.62)
/// Przechowuje wartosc `neonOrange`.
  static let neonOrange = Color(red: 1.00, green: 0.55, blue: 0.20)
/// Przechowuje wartosc `neonYellow`.
  static let neonYellow = Color(red: 1.00, green: 0.92, blue: 0.22)

/// Wykonuje operacje `glow`.
  static func glow(_ color: Color, radius: CGFloat = 10) -> some ViewModifier {
    GlowModifier(color: color, radius: radius)
  }
}

private struct GlowModifier: ViewModifier {
/// Przechowuje wartosc `color`.
  let color: Color
/// Przechowuje wartosc `radius`.
  let radius: CGFloat

/// Wykonuje operacje `body`.
  func body(content: Content) -> some View {
    content
      .shadow(color: color.opacity(0.65), radius: radius, x: 0, y: 0)
      .shadow(color: color.opacity(0.35), radius: radius * 1.6, x: 0, y: 0)
  }
}

/// Rozszerza istniejacy typ o dodatkowe zachowanie.
extension View {
/// Wykonuje operacje `neonGlow`.
  func neonGlow(_ color: Color, radius: CGFloat = 10) -> some View {
    modifier(NeonTheme.glow(color, radius: radius))
  }
}

