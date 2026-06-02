import AVKit
import SwiftUI

/// Przycisk AirPlay (TV / głośniki) — systemowy picker Apple.
struct AirPlayRoutePicker: UIViewRepresentable {
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  var scale: CGFloat = 1.0

  /// Wykonuje operację `makeUIView` w bieżącym kontekście gry/UI.
  func makeUIView(context: Context) -> AVRoutePickerView {
    let view = AVRoutePickerView()
    view.activeTintColor = UIColor(NeonTheme.neonYellow)
    view.tintColor = UIColor.white
    view.prioritizesVideoDevices = true
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = true
    if scale != 1 {
      view.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
    return view
  }

  /// Wykonuje operację `updateUIView` w bieżącym kontekście gry/UI.
  func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
    uiView.prioritizesVideoDevices = true
    uiView.activeTintColor = UIColor(NeonTheme.neonYellow)
  }
}

/// Opisuje extension `AirPlayRoutePicker` używany przez warstwę UI i logikę gry.
extension AirPlayRoutePicker {
  /// Wykonuje operację `airPlayHitTarget` w bieżącym kontekście gry/UI.
  func airPlayHitTarget(size: CGFloat = 52) -> some View {
    frame(width: size, height: size)
      .contentShape(Rectangle())
  }
}

/// Panel podłączenia TV (quiz, dart).
struct TVConnectPanel: View {
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay
  /// Przechowuje wartość `hint` wykorzystywaną przez dany komponent.
  var hint: String = "Centrum sterowania → Odbicie ekranu też działa · na TV widać grę w trybie teleturnieju"

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 14) {
        Image(systemName: "tv.fill")
          .font(.system(size: 32, weight: .bold))
          .foregroundStyle(NeonTheme.neonYellow)
          .neonGlow(NeonTheme.neonYellow, radius: 6)

        VStack(alignment: .leading, spacing: 4) {
          Text("EKRAN TELEWIZORA")
            .font(.system(size: 15, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
          Text(quizDisplay.isExternalScreenConnected ? "● NA ŻYWO — TV podłączone" : "Podłącz Apple TV lub odbicie ekranu")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(quizDisplay.isExternalScreenConnected ? NeonTheme.neonGreen : .white.opacity(0.65))
        }
        Spacer(minLength: 0)
      }

      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(
            LinearGradient(
              colors: [
                Color(red: 0.12, green: 0.08, blue: 0.02),
                Color(red: 0.06, green: 0.05, blue: 0.12),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        RoundedRectangle(cornerRadius: 4)
          .strokeBorder(
            LinearGradient(
              colors: [NeonTheme.neonYellow, NeonTheme.neonOrange.opacity(0.8)],
              startPoint: .leading,
              endPoint: .trailing
            ),
            lineWidth: 2.5
          )

        HStack(spacing: 14) {
          Image(systemName: "airplayvideo")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(NeonTheme.neonYellow)
          VStack(alignment: .leading, spacing: 3) {
            Text("PODŁĄCZ TV")
              .font(.system(size: 18, weight: .heavy, design: .monospaced))
              .foregroundStyle(.white)
            Text("Dotknij · wybierz Apple TV")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.white.opacity(0.55))
          }
          Spacer()
          AirPlayRoutePicker(scale: 2.4)
            .airPlayHitTarget(size: 64)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
      }
      .frame(minHeight: 88)

      Text(hint)
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.45))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(Color(red: 0.05, green: 0.04, blue: 0.10).opacity(0.95))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(NeonTheme.neonCyan.opacity(0.35), lineWidth: 1)
    )
  }
}

/// Definiuje alias typu `QuizTVConnectPanel` dla czytelniejszego API.
typealias QuizTVConnectPanel = TVConnectPanel
