import SwiftUI
import TrikiMotionKit

private let calibrationRefreshInterval = 0.15

struct GameCalibrationView: View {
  let gameType: GameType
  @ObservedObject var inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning

  @State private var startGame = false

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      VStack(spacing: 16) {
        Text("Kalibracja")
          .font(.system(size: 22, weight: .heavy, design: .monospaced))
          .foregroundStyle(.cyan)

        Text(gameType.rawValue.uppercased())
          .font(.system(size: 14, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)

        instructionBlock

        Text("📱 Trzymaj telefon pionowo — obszar gry wypełni ekran")
          .font(.system(size: 11, weight: .bold, design: .monospaced))
          .foregroundStyle(.cyan.opacity(0.9))
          .multilineTextAlignment(.center)

        pointerMeter

        presetReadout

        debugReadout

        statusLine

        Button {
          var axes = inputProvider.config.axisMapping
          axes.invertX.toggle()
          inputProvider.config.axisMapping = axes
          inputProvider.flipPaddleOffsetSign()
        } label: {
          Text("Odwróć lewo/prawo")
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.mint)
        .disabled(!hasMotionSignal)

        Button(action: beginGame) {
          Text("Graj")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)

        if !hasMotionSignal {
          Text("Bez BLE możesz grać od razu. Z kontrolerem — połącz w menu (ikona fal).")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
        }

        Spacer(minLength: 0)
      }
      .padding(16)
    }
    .navigationTitle("Kalibracja")
    .navigationBarTitleDisplayMode(.inline)
    .fullScreenCover(isPresented: $startGame) {
      GameView(gameType: gameType, inputProvider: inputProvider, tuning: tuning)
    }
    .onAppear {
      GameManager.applyMotionMode(gameType: gameType, to: inputProvider)
    }
    .background {
      if !startGame {
        TimelineView(.periodic(from: .now, by: calibrationRefreshInterval)) { timeline in
          Color.clear
            .onChange(of: timeline.date.timeIntervalSinceReferenceDate, initial: true) { _, _ in
              _ = inputProvider.pollInput()
            }
        }
      }
    }
  }

  private var hasMotionSignal: Bool {
    inputProvider.isReceiving || inputProvider.isConnected
  }

  private func beginGame() {
    if hasMotionSignal {
      inputProvider.motionSDK.engine.resetPaddleMotion()
    }
    startGame = true
  }

  private var instructionBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("1. Weź Triki do ręki — środek ustawia się sam")
      Text("2. Skręć lewo/prawo — paletka jedzie 1:1")
      Text("3. Puść / odłóż — offset wraca do neutralu")
      Text("4. Zły kierunek? „Odwróć lewo/prawo”")
    }
    .font(.system(size: 12, design: .monospaced))
    .foregroundStyle(.white.opacity(0.9))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.white.opacity(0.06))
    .overlay(Rectangle().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
  }

  private var pointerMeter: some View {
    let posX = inputProvider.liveInput.posX
    let magnitude = min(abs(posX), 1)
    return VStack(spacing: 8) {
      Text("POS X \(String(format: "%+.2f", posX))")
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)

      GeometryReader { geo in
        let center = geo.size.width / 2
        let barWidth = geo.size.width * magnitude
        ZStack(alignment: .leading) {
          Rectangle()
            .fill(Color.white.opacity(0.1))
          if posX < 0 {
            Rectangle()
              .fill(Color.cyan)
              .frame(width: barWidth)
              .offset(x: center - barWidth)
          } else if posX > 0 {
            Rectangle()
              .fill(Color.cyan)
              .frame(width: barWidth)
              .offset(x: center)
          }
          Rectangle()
            .fill(Color(red: 1, green: 0.25, blue: 0.75))
            .frame(width: 2)
            .offset(x: center - 1)
        }
      }
      .frame(height: 24)
    }
  }

  private var presetReadout: some View {
    let cfg = inputProvider.config
    return VStack(alignment: .leading, spacing: 4) {
      Text("TRYB \(cfg.mode.rawValue.uppercased()) · preset")
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .foregroundStyle(.cyan.opacity(0.9))
      Text("deadzone \(String(format: "%.3f", cfg.deadzone))")
      switch cfg.mode {
      case .paddle:
        Text("smooth \(String(format: "%.2f/%.2f", cfg.paddleSmoothRetain, cfg.paddleSmoothBlend)) · microDZ \(String(format: "%.2f", cfg.paddleMicroDeadzone))")
      case .pointer:
        Text("sens \(String(format: "%.3f", cfg.pointerSensitivity)) · damp \(String(format: "%.2f", cfg.pointerRotDamping))")
      case .gesture:
        Text("sens \(String(format: "%.3f", cfg.pointerSensitivity)) · shot ≥ \(String(format: "%.2f", cfg.gestureThreshold))")
      }
    }
    .font(.system(size: 10, design: .monospaced))
    .foregroundStyle(.white.opacity(0.65))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(Color.white.opacity(0.04))
  }

  private var debugReadout: some View {
    let input = inputProvider.liveInput
    return VStack(alignment: .leading, spacing: 4) {
      let locked = inputProvider.motionSDK.debug.paddleOffsetLocked ? "AUTO" : "…"
      let dbg = inputProvider.motionSDK.debug
      Text("RAW \(String(format: "%+.0f", input.moveX))  OFF \(String(format: "%+.0f", dbg.biasX))  Δ \(String(format: "%+.0f", dbg.paddleRawDelta))  pos \(String(format: "%+.2f", input.posX))")
      Text("VY \(String(format: "%+.3f", input.velocityY))  \(input.pointerDirection.rawValue)")
    }
    .font(.system(size: 11, weight: .bold, design: .monospaced))
    .foregroundStyle(.yellow)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var statusLine: some View {
    let text: String
    let color: Color

    if hasMotionSignal {
      text = "Auto-kalibracja w tle — bez klikania, po prostu Graj"
      color = .green
    } else {
      text = "Brak kontrolera — możesz grać bez BLE"
      color = .orange
    }

    return Text(text)
      .font(.system(size: 11, weight: .bold, design: .monospaced))
      .foregroundStyle(color)
      .multilineTextAlignment(.center)
  }
}
