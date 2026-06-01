import SwiftUI
import VeltoKit

struct ConnectView: View {
  @EnvironmentObject private var motion: MotionInputProvider
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 16) {
      Text("Połączenie kontrolera")
        .font(.headline)

      HStack {
        Circle()
          .fill(motion.isConnected ? Color.green : Color.red)
          .frame(width: 10, height: 10)
        Text(connectionStatusText)
          .font(.subheadline.monospaced())
      }

      ArcadeUI.primaryButton(
        motion.isConnected ? "ROZŁĄCZ" : "POŁĄCZ",
        color: motion.isConnected ? NeonTheme.neonOrange : NeonTheme.neonGreen,
        icon: "dot.radiowaves.left.and.right"
      ) {
        motion.isConnected ? motion.disconnect() : motion.connect()
      }

      ArcadeUI.secondaryButton("KALIBRACJA", tint: .mint) {
        guard motion.isReceiving else { return }
        motion.presentCalibrationPrompt()
        dismiss()
      }
      .opacity(motion.isReceiving ? 1 : 0.45)
      .disabled(!motion.isReceiving)

      ArcadeUI.secondaryButton("ZAMKNIJ", tint: .white.opacity(0.7)) {
        dismiss()
      }

      Text("Sterowanie dotykiem")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(20)
  }

  private var connectionStatusText: String {
    if motion.isReceiving { return "connected · odbiór" }
    if motion.isConnected { return "connected · brak pakietów" }
    return "not connected"
  }
}
