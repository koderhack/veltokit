import SwiftUI

/// Wspólne elementy UI (neon / pixel arcade).
enum ArcadeUI {
/// Przechowuje wartosc `screenBackground`.
  static var screenBackground: some View {
    LinearGradient(
      colors: [
        Color(red: 0.03, green: 0.03, blue: 0.07),
        NeonTheme.bg,
        Color(red: 0.06, green: 0.02, blue: 0.10),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }

/// Wykonuje operacje `sectionLabel`.
  static func sectionLabel(_ text: String) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .heavy, design: .monospaced))
      .foregroundStyle(NeonTheme.neonCyan.opacity(0.95))
      .frame(maxWidth: .infinity, alignment: .leading)
  }

/// Wykonuje operacje `panel`.
  static func panel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
      .padding(14)
      .background(NeonTheme.panel)
      .overlay(
        Rectangle()
          .strokeBorder(
            LinearGradient(
              colors: [NeonTheme.neonCyan.opacity(0.5), Color.white.opacity(0.12)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      )
  }

/// Wykonuje operacje `primaryButton`.
  static func primaryButton(
    _ title: String,
    color: Color = NeonTheme.neonGreen,
    icon: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 13, weight: .bold))
        }
        Text(title)
          .font(.system(size: 14, weight: .heavy, design: .monospaced))
      }
      .foregroundStyle(Color.black.opacity(0.92))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
      .background(color)
      .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
    }
    .buttonStyle(.plain)
    .neonGlow(color, radius: 8)
  }

/// Wykonuje operacje `secondaryButton`.
  static func secondaryButton(
    _ title: String,
    tint: Color = NeonTheme.neonCyan,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(.system(size: 12, weight: .bold, design: .monospaced))
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tint.opacity(0.12))
        .overlay(Rectangle().stroke(tint.opacity(0.45), lineWidth: 1))
    }
    .buttonStyle(.plain)
  }

/// Wykonuje operacje `gameCard`.
  static func gameCard(
    title: String,
    subtitle: String,
    accent: Color,
    icon: String
  ) -> some View {
    HStack(spacing: 14) {
      ZStack {
        Rectangle()
          .fill(accent.opacity(0.2))
          .frame(width: 44, height: 44)
        Image(systemName: icon)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(accent)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 15, weight: .heavy, design: .monospaced))
        Text(subtitle)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(Color.white.opacity(0.65))
          .lineLimit(2)
      }
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(accent)
    }
    .foregroundStyle(.white)
    .padding(12)
    .background(
      LinearGradient(
        colors: [accent.opacity(0.22), Color.white.opacity(0.04)],
        startPoint: .leading,
        endPoint: .trailing
      )
    )
    .overlay(Rectangle().stroke(accent.opacity(0.55), lineWidth: 1))
    .contentShape(Rectangle())
  }

/// Wykonuje operacje `neonProgressBar`.
  static func neonProgressBar(progress: Double, accent: Color = NeonTheme.neonCyan) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Rectangle()
          .fill(Color.white.opacity(0.08))
        Rectangle()
          .fill(
            LinearGradient(
              colors: [accent.opacity(0.7), accent],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: max(0, geo.size.width * min(1, max(0, progress))))
          .neonGlow(accent, radius: 6)
      }
    }
    .frame(height: 10)
    .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
  }

/// Wykonuje operacje `hudBar`.
  static func hudBar(title: String, onExit: @escaping () -> Void, linkActive: Bool) -> some View {
    HStack(spacing: 10) {
      Button(action: onExit) {
        Image(systemName: "xmark")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(.white)
          .frame(width: 36, height: 36)
          .background(Color.white.opacity(0.1))
          .overlay(Rectangle().stroke(Color.white.opacity(0.25), lineWidth: 1))
      }
      .buttonStyle(.plain)

      Text(title)
        .font(.system(size: 12, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white.opacity(0.9))

      Spacer()

      HStack(spacing: 6) {
        Circle()
          .fill(linkActive ? NeonTheme.neonGreen : Color.red.opacity(0.9))
          .frame(width: 8, height: 8)
        Text(linkActive ? "BLE" : "OFF")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.55))
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(Color.black.opacity(0.35))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color.black.opacity(0.55))
    .overlay(Rectangle().stroke(NeonTheme.neonCyan.opacity(0.25), lineWidth: 1))
  }
}

/// Pełnoekranowy canvas + nakładka UI poniżej wycięcia / Dynamic Island.
struct GameScreenLayout<Overlay: View>: View {
/// Przechowuje wartosc `commands`.
  let commands: [DrawCommand]
/// Przechowuje wartosc `canvasDisplayMode`.
  var canvasDisplayMode: PixelCanvasDisplayMode = .portraitPhone
/// Przechowuje wartosc `horizontalPadding`.
  var horizontalPadding: CGFloat = 10
/// Przechowuje wartosc `topExtraPadding`.
  var topExtraPadding: CGFloat = 4
/// Przechowuje wartosc `bottomExtraPadding`.
  var bottomExtraPadding: CGFloat = 10
  @ViewBuilder let overlay: () -> Overlay

/// Przechowuje wartosc `body`.
  var body: some View {
    GeometryReader { geo in
/// Przechowuje wartosc `insets`.
      let insets = geo.safeAreaInsets
      ZStack {
        Color.black
        PixelCanvas(
          commands: commands,
          gridWidth: GameContext.width,
          gridHeight: GameContext.height,
          displayMode: canvasDisplayMode
        )
        .equatable()
        .frame(width: geo.size.width, height: geo.size.height)
        .ignoresSafeArea()

        overlay()
          .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
          .padding(.top, insets.top + topExtraPadding)
          .padding(.bottom, insets.bottom + bottomExtraPadding)
          .padding(.leading, insets.leading + horizontalPadding)
          .padding(.trailing, insets.trailing + horizontalPadding)
      }
    }
    .background(Color.black)
  }
}
