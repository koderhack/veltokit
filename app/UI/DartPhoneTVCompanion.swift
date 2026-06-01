import SwiftUI
import VeltoKit

/// Minimalny pilot na telefonie — menu i gra na TV.
struct DartPhoneTVCompanion: View {
  @ObservedObject var inputProvider: MotionInputProvider
  var tvConnected: Bool = false
  let title: String
  let subtitle: String

  private var trikiControlHint: String {
    tvConnected
      ? "Triki steruje tylko TV — na telefonie używaj przycisków"
      : "Obrót Triki = wybór · hold lub przycisk = OK"
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "tv.fill")
        .font(.system(size: 40, weight: .semibold))
        .foregroundStyle(NeonTheme.neonYellow)

      Text(title)
        .font(.system(size: 20, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonCyan)
        .multilineTextAlignment(.center)

      Text(subtitle)
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.65))
        .multilineTextAlignment(.center)

      connectionRow

      Text(trikiControlHint)
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .foregroundStyle(NeonTheme.neonYellow.opacity(0.9))
        .multilineTextAlignment(.center)
    }
    .padding(20)
    .frame(maxWidth: .infinity)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.black.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(NeonTheme.neonCyan.opacity(0.35), lineWidth: 1.5))
    )
  }

  private var connectionRow: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(inputProvider.isReceiving ? NeonTheme.neonGreen : (inputProvider.isConnected ? NeonTheme.neonOrange : .red))
        .frame(width: 9, height: 9)
      Text(inputProvider.isConnected ? "Triki połączony" : "Podłącz Triki (Bluetooth)")
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.8))
    }
  }
}
