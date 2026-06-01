import SwiftUI
import Combine
import VeltoKit

private let devModeRefreshInterval = 0.12

struct DevModeView: View {
  @EnvironmentObject private var motion: MotionInputProvider

  @State private var inputSnapshot = GameInput()
  @State private var uiTick = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        bleDebugSection
        motionSection
        configSection
        axisSection
        actionsSection
      }
      .padding(16)
    }
    .background(Color(red: 0.04, green: 0.04, blue: 0.08).ignoresSafeArea())
    .navigationTitle("DEV MODE")
    .navigationBarTitleDisplayMode(.inline)
    .font(.system(.body, design: .monospaced))
    .foregroundStyle(.white)
    .onAppear { refreshSnapshot() }
    .onReceive(Timer.publish(every: devModeRefreshInterval, on: .main, in: .common).autoconnect()) { _ in
      refreshSnapshot()
    }
  }

  private var bleDebugSection: some View {
    let probe = motion.bleByteProbe
    let candidates = probe.risingZeroToOneIndices
    let candidateText = candidates.isEmpty ? "—" : candidates.map(String.init).joined(separator: ", ")
    let _ = uiTick

    return devSection("BLE — SZUKAJ PRZYCISKU") {
      Text("Włącz log, połącz Triki, klikaj przycisk. W Xcode Console szukaj CHG / EDGE / CLICK?")
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.white.opacity(0.55))

      Toggle(
        "Log surowe RX (print + diff)",
        isOn: Binding(
          get: { motion.debugBLEBytes },
          set: { motion.debugBLEBytes = $0 }
        )
      )
      Toggle(
        "Hex każdego pakietu",
        isOn: Binding(
          get: { motion.logBLEPacketsInDevMode },
          set: { motion.logBLEPacketsInDevMode = $0 }
        )
      )

      HStack {
        devButton("RESET PROBE") { motion.resetBLEProbe() }
        devButton("WYCZYŚĆ LOG") { motion.clearBLEDevLog() }
      }

      row("ostatni pakiet", probe.lastPacketHex)
      row("kandydaci 0→1", candidateText)
      row("bytes[1]", "\(motion.debugBLEButtonB1)")
      row("parser click", motion.debugParserClick ? "TAK" : "nie")
      row("primaryAction", inputSnapshot.primaryAction ? "TAK" : "nie")
      row("input.sensors.click", inputSnapshot.sensors.click ? "TAK" : "nie")

      if !probe.lastChanges.isEmpty {
        Text("Ostatnie zmiany bajtów")
          .foregroundStyle(NeonTheme.neonYellow)
          .font(.system(size: 10, weight: .bold, design: .monospaced))
        ForEach(probe.lastChanges, id: \.index) { ch in
          Text("[\(ch.index)] \(ch.from)→\(ch.to)\(ch.from == 0 && ch.to == 1 ? " 🔥" : "")")
            .font(.system(size: 10, design: .monospaced))
        }
      }

      Text("Probe / log")
        .foregroundStyle(.cyan)
        .font(.system(size: 10, weight: .bold, design: .monospaced))
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          ForEach(Array(probe.recentLines.enumerated()).suffix(24), id: \.offset) { _, line in
            Text(line).font(.system(size: 9, design: .monospaced))
          }
          ForEach(Array(motion.bleDevLog.suffix(16).enumerated()), id: \.offset) { _, line in
            Text(line).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
          }
        }
      }
      .frame(maxHeight: 88)
    }
  }

  private var motionSection: some View {
    let dbg = motion.motionSDK.debug
    let input = inputSnapshot
    return devSection("MOTION SDK") {
      row("tryb", motion.config.mode.rawValue)
      row("rawX/Y", String(format: "%+.3f / %+.3f", dbg.rawX, dbg.rawY))
      row("smooth", String(format: "%+.3f / %+.3f", dbg.smoothX, dbg.smoothY))
      row("rel", String(format: "%+.3f / %+.3f", dbg.relX, dbg.relY))
      row("biasX", String(format: "%+.3f", dbg.biasX))
      row("kierunek", dbg.paddleDirection)
      row("rot / gz", String(format: "%+.3f / %+.3f", dbg.paddleRotation, dbg.paddleGyroZ))
      row("steer", String(format: "%+.3f", dbg.paddleSteer))
      row("pos", String(format: "%+.3f / %+.3f", input.posX, input.posY))
      row("velocityX", String(format: "%+.3f", dbg.velocityX))
      row("gyro blk", "\(dbg.gyroBlockIndex)")
      row("shot", input.shotTriggered ? "1" : "0")
    }
  }

  /// Aktywny preset trybu — tylko odczyt (wartości ustawiane przez `MotionConfig.preset`).
  private var configSection: some View {
    let cfg = motion.config
    return devSection("PRESET (tylko odczyt)") {
      row("deadzone", fmt(cfg.deadzone))
      row("smooth", fmt(cfg.inputSmoothing))
      row("ref drift", cfg.referenceDriftEnabled ? "on" : "off")
      row("ref blend", fmt(cfg.referenceBlend))

      row("sensor", cfg.sensorInput.rawValue)

      switch cfg.mode {
      case .paddle:
        row("gain", fmt(cfg.paddlePositionGain))
        row("follow", fmt(cfg.paddlePositionFollow))
        row("gyro+", fmt(cfg.paddleGyroAssist))
        row("zero snap", fmt(cfg.paddleZeroSnap))
        row("bias", "\(fmt(cfg.paddleBiasRetain)) / \(fmt(cfg.paddleBiasBlend))")
        row("ref", "\(fmt(cfg.referenceRetain)) / \(fmt(cfg.referenceBlend))")
      case .pointer:
        row("pointerSens", fmt(cfg.pointerSensitivity))
        row("rot damp", fmt(cfg.pointerRotDamping))
        row("out smooth", fmt(cfg.pointerOutputSmoothing))
      case .gesture:
        row("pointerSens", fmt(cfg.pointerSensitivity))
        row("rot damp", fmt(cfg.pointerRotDamping))
        row("gesture ≥", fmt(cfg.gestureThreshold))
        row("gest CD", String(format: "%.2fs", cfg.gestureCooldown))
        row("min relY", fmt(cfg.gestureMinRelY))
      }
    }
  }

  private var axisSection: some View {
    devSection("AXIS MAP") {
      Picker("inputX", selection: axisBinding(\.inputX)) {
        ForEach(MotionAxisSource.allCases, id: \.self) { src in
          Text(src.rawValue).tag(src)
        }
      }
      Picker("inputY", selection: axisBinding(\.inputY)) {
        ForEach(MotionAxisSource.allCases, id: \.self) { src in
          Text(src.rawValue).tag(src)
        }
      }
      Toggle("invertX", isOn: invertBinding(\.invertX))
      Toggle("invertY", isOn: invertBinding(\.invertY))
    }
  }

  private var actionsSection: some View {
    devSection("ACTIONS") {
      HStack {
        devButton("PADDLE") { GameManager.applyMode(.paddle, to: motion) }
        devButton("POINTER") { GameManager.applyMode(.pointer, to: motion) }
        devButton("GESTURE") { GameManager.applyMode(.gesture, to: motion) }
      }
      HStack {
        devButton("CONNECT") { motion.connect() }
        devButton("RESET") { motion.resetInputState() }
        devButton("ZERO") { motion.calibrateCenter() }
      }
    }
  }

  private func axisBinding(_ keyPath: WritableKeyPath<MotionAxisMapping, MotionAxisSource>) -> Binding<MotionAxisSource> {
    Binding(
      get: { motion.config.axisMapping[keyPath: keyPath] },
      set: {
        var m = motion.config.axisMapping
        m[keyPath: keyPath] = $0
        motion.config.axisMapping = m
      }
    )
  }

  private func invertBinding(_ keyPath: WritableKeyPath<MotionAxisMapping, Bool>) -> Binding<Bool> {
    Binding(
      get: { motion.config.axisMapping[keyPath: keyPath] },
      set: {
        var m = motion.config.axisMapping
        m[keyPath: keyPath] = $0
        motion.config.axisMapping = m
      }
    )
  }

  private func fmt(_ value: Double) -> String {
    String(format: "%.3f", value)
  }

  private func devSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).foregroundStyle(.cyan)
      content()
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white.opacity(0.06))
  }

  private func row(_ label: String, _ value: String) -> some View {
    HStack {
      Text(label).foregroundStyle(.white.opacity(0.55)).frame(width: 88, alignment: .leading)
      Text(value)
    }
    .font(.system(size: 11, design: .monospaced))
  }

  private func devButton(_ title: String, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
      .font(.system(size: 10, weight: .bold, design: .monospaced))
      .foregroundStyle(.black)
      .padding(8)
      .background(Color.cyan)
  }

  private func refreshSnapshot() {
    _ = motion.pollInput()
    inputSnapshot = motion.snapshotInput()
    uiTick &+= 1
  }
}
