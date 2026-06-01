import SwiftUI

enum NeonTheme {
  static let bg = Color(red: 0.03, green: 0.03, blue: 0.06)
  static let panel = Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.9)

  static let neonCyan = Color(red: 0.25, green: 0.92, blue: 1.00)
  static let neonMagenta = Color(red: 1.00, green: 0.22, blue: 0.80)
  static let neonGreen = Color(red: 0.22, green: 1.00, blue: 0.62)
  static let neonOrange = Color(red: 1.00, green: 0.55, blue: 0.20)
  static let neonYellow = Color(red: 1.00, green: 0.92, blue: 0.22)

  static func glow(_ color: Color, radius: CGFloat = 10) -> some ViewModifier {
    GlowModifier(color: color, radius: radius)
  }
}

private struct GlowModifier: ViewModifier {
  let color: Color
  let radius: CGFloat

  func body(content: Content) -> some View {
    content
      .shadow(color: color.opacity(0.65), radius: radius, x: 0, y: 0)
      .shadow(color: color.opacity(0.35), radius: radius * 1.6, x: 0, y: 0)
  }
}

extension View {
  func neonGlow(_ color: Color, radius: CGFloat = 10) -> some View {
    modifier(NeonTheme.glow(color, radius: radius))
  }
}

