import SwiftUI
import TrikiMotionKit

struct ConnectView: View {
  @EnvironmentObject private var motion: MotionInputProvider

  var body: some View {
    VStack(spacing: 16) {
      Text("Połączenie kontrolera")
        .font(.headline)

      HStack {
        Circle()
          .fill(motion.isConnected ? Color.green : Color.red)
          .frame(width: 10, height: 10)
        Text(motion.isConnected ? "connected" : "not connected")
          .font(.subheadline.monospaced())
      }

      Button {
        motion.isConnected ? motion.disconnect() : motion.connect()
      } label: {
        Text(motion.isConnected ? "Disconnect" : "Connect")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)

      Button {
        motion.zeroNeutralTilt()
      } label: {
        Text("Wyzeruj neutral")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.bordered)
      .disabled(!motion.isReceiving)

      Text("Trzymaj kontroler prosto i naciśnij „Wyzeruj”, gdy paleta sama się przesuwa.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Text("SDK API: connect(), disconnect(), pollInput(), zeroNeutralTilt()")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(20)
  }
}
