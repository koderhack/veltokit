import SwiftUI
import VeltoKit

/// Ekran po połączeniu BLE — użytkownik trzyma Triki i zatwierdza kalibrację.
struct TrikiCalibrationView: View {
  @EnvironmentObject private var motion: MotionInputProvider
  @Environment(\.dismiss) private var dismiss

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    ZStack {
      ArcadeUI.screenBackground

      VStack(spacing: 28) {
        Spacer(minLength: 0)

        Image(systemName: "gamecontroller.fill")
          .font(.system(size: 52, weight: .bold))
          .foregroundStyle(NeonTheme.neonCyan)

        VStack(spacing: 12) {
          Text("TRZYMAJ TRIKI W RĘCE")
            .font(.system(size: 26, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)

          Text("Ustaw kontroler naturalnie.\nLekko wyprostuj — potem naciśnij kalibruj.")
            .font(.system(size: 14, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        }
        .padding(.horizontal, 24)

        signalCard

        VStack(spacing: 12) {
          Button(action: calibrate) {
            Text("KALIBRUJ")
              .font(.system(size: 18, weight: .heavy, design: .monospaced))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
              .background(NeonTheme.neonGreen)
              .foregroundStyle(.black)
          }
          .buttonStyle(.plain)
          .disabled(!motion.isReceiving)

          Button(action: skip) {
            Text("PÓŹNIEJ")
              .font(.system(size: 13, weight: .bold, design: .monospaced))
              .foregroundStyle(.white.opacity(0.55))
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)

        Spacer(minLength: 0)
      }
      .padding(.vertical, 32)
    }
    .interactiveDismissDisabled()
    .onAppear {
      GameManager.applyUIMode(to: motion)
    }
    .background {
      TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { _ in
        Color.clear.onAppear {
          _ = motion.pollInput()
        }
      }
    }
  }

  private var signalCard: some View {
    let input = motion.liveInput
    let ready = motion.isReceiving

    return VStack(spacing: 10) {
      HStack {
        Circle()
          .fill(ready ? NeonTheme.neonGreen : Color.red.opacity(0.85))
          .frame(width: 10, height: 10)
        Text(ready ? "Sygnał BLE OK" : "Czekam na dane z Triki…")
          .font(.system(size: 12, weight: .bold, design: .monospaced))
          .foregroundStyle(ready ? NeonTheme.neonGreen : NeonTheme.neonOrange)
        Spacer()
        Text("pos \(String(format: "%+.2f", input.posX))")
          .font(.system(size: 12, weight: .bold, design: .monospaced))
          .foregroundStyle(NeonTheme.neonYellow)
      }

      GeometryReader { geo in
        let center = geo.size.width / 2
        let bar = geo.size.width * min(1, abs(input.posX))
        ZStack(alignment: .leading) {
          Rectangle().fill(Color.white.opacity(0.1))
          if input.posX < 0 {
            Rectangle()
              .fill(NeonTheme.neonCyan)
              .frame(width: bar)
              .offset(x: center - bar)
          } else if input.posX > 0 {
            Rectangle()
              .fill(NeonTheme.neonCyan)
              .frame(width: bar)
              .offset(x: center)
          }
          Rectangle()
            .fill(NeonTheme.neonMagenta)
            .frame(width: 2)
            .offset(x: center - 1)
        }
      }
      .frame(height: 24)
    }
    .padding(14)
    .background(Color.white.opacity(0.06))
    .overlay(Rectangle().stroke(Color.white.opacity(0.15), lineWidth: 1))
    .padding(.horizontal, 24)
  }

  private func calibrate() {
    motion.performCalibration()
    dismiss()
  }

  private func skip() {
    motion.skipCalibrationPrompt()
    dismiss()
  }
}
