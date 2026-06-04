import SwiftUI
import VeltoKit

struct ConnectView: View {
  @EnvironmentObject private var motion: MotionInputProvider
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 16) {
      Text("Połączenie kontrolera")
        .font(.headline)

      statusCard

      ArcadeUI.primaryButton(
        motion.isConnected ? "ROZŁĄCZ" : "POŁĄCZ",
        color: motion.isConnected ? NeonTheme.neonOrange : NeonTheme.neonGreen,
        icon: "dot.radiowaves.left.and.right"
      ) {
        motion.isConnected ? motion.disconnect() : motion.connect()
      }

      if motion.hasCachedDevice, !motion.isConnected {
        ArcadeUI.secondaryButton("OSTATNIE URZĄDZENIE", tint: NeonTheme.neonCyan) {
          motion.connectLastDevice()
        }
      }

      ArcadeUI.secondaryButton("ZAMKNIJ", tint: .white.opacity(0.7)) {
        dismiss()
      }

      Text("Sterowanie dotykiem zawsze dostępne w menu.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(20)
    .motionInputPolling(motion)
  }

  private var statusCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Circle()
          .fill(statusDotColor)
          .frame(width: 10, height: 10)
        Text(connectionStatusText)
          .font(.subheadline.monospaced())
        Spacer()
        if motion.isConnected {
          Text(motion.bleMode.statusLabel)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(motion.bleMode.uiColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(motion.bleMode.uiColor.opacity(0.15))
            .clipShape(Capsule())
        }
      }

      Text(motion.bleMode.connectionHint)
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)

      if let idle = motion.idleStatusMessage {
        Label(idle, systemImage: "moon.zzz.fill")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(NeonTheme.neonOrange)
      } else if motion.isTrikiGameplayActive {
        Label("Gotowy do gry", systemImage: "gamecontroller.fill")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(NeonTheme.neonGreen)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.white.opacity(0.06))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.12), lineWidth: 1))
  }

  private var statusDotColor: Color {
    if !motion.isConnected { return .red }
    if motion.isTrikiGameplayActive { return motion.bleMode.uiColor }
    if motion.isReceiving || motion.bleMode == .lowPower { return NeonTheme.neonOrange }
    return .orange
  }

  private var connectionStatusText: String {
    if !motion.isConnected { return "brak połączenia" }
    if motion.isTrikiGameplayActive { return "live · \(motion.bleMode.statusLabel.lowercased())" }
    if motion.isReceiving { return "odbiór · \(motion.bleMode.statusLabel.lowercased())" }
    if motion.bleMode == .lowPower { return "połączono · czuwanie" }
    return "połączono · brak pakietów"
  }
}
