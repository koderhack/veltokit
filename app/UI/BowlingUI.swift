import SceneKit
import SwiftUI
import UIKit

/// Opisuje struct `BowlingScoreboardView` używany przez warstwę UI i logikę gry.
struct BowlingScoreboardView: View {
  /// Opisuje enum `Style` używany przez warstwę UI i logikę gry.
  enum Style {
    /// Telefon — gra na ekranie telefonu.
    case phone
    /// Telefon — pilot przy torze na TV (najwięcej miejsca na tabelę).
    case phonePilot
    /// Telewizor — pełna szerokość, duża typografia.
    case tv
  }

  /// Przechowuje wartość `players` wykorzystywaną przez dany komponent.
  let players: [BowlingGameLogic.Player]
  /// Przechowuje wartość `currentPlayerIndex` wykorzystywaną przez dany komponent.
  let currentPlayerIndex: Int
  /// Przechowuje wartość `currentFrame` wykorzystywaną przez dany komponent.
  let currentFrame: Int
  /// Przechowuje wartość `style` wykorzystywaną przez dany komponent.
  var style: Style = .phone
  /// Dodatkowy mnożnik (np. skala TV).
  var scale: CGFloat = 1

  private struct Metrics {
    let nameSize: CGFloat
    let totalSize: CGFloat
    let cellWidth: CGFloat
    let numSize: CGFloat
    let rollSize: CGFloat
    let scoreSize: CGFloat
    let rowPadding: CGFloat
    let cellVPad: CGFloat
    let rowSpacing: CGFloat
    let frameSpacing: CGFloat
    let stackSpacing: CGFloat
    let maxHeight: CGFloat
  }

  private var metrics: Metrics {
    let base: Metrics
    switch style {
    case .phone:
      base = Metrics(
        nameSize: 13, totalSize: 17, cellWidth: 38,
        numSize: 10, rollSize: 11, scoreSize: 12,
        rowPadding: 10, cellVPad: 5, rowSpacing: 5,
        frameSpacing: 4, stackSpacing: 8, maxHeight: 240
      )
    case .phonePilot:
      base = Metrics(
        nameSize: 15, totalSize: 20, cellWidth: 44,
        numSize: 11, rollSize: 13, scoreSize: 14,
        rowPadding: 12, cellVPad: 6, rowSpacing: 6,
        frameSpacing: 5, stackSpacing: 10, maxHeight: 300
      )
    case .tv:
      base = Metrics(
        nameSize: 18, totalSize: 24, cellWidth: 52,
        numSize: 14, rollSize: 16, scoreSize: 17,
        rowPadding: 14, cellVPad: 8, rowSpacing: 8,
        frameSpacing: 6, stackSpacing: 12, maxHeight: 360
      )
    }
    let s = max(1, scale)
    return Metrics(
      nameSize: base.nameSize * s,
      totalSize: base.totalSize * s,
      cellWidth: base.cellWidth * s,
      numSize: base.numSize * s,
      rollSize: base.rollSize * s,
      scoreSize: base.scoreSize * s,
      rowPadding: base.rowPadding * s,
      cellVPad: base.cellVPad * s,
      rowSpacing: base.rowSpacing * s,
      frameSpacing: base.frameSpacing * s,
      stackSpacing: base.stackSpacing * s,
      maxHeight: base.maxHeight * s
    )
  }

  private var isPartyLayout: Bool { players.count > 6 }

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    let m = metrics
    if isPartyLayout {
      partyScoreboard(metrics: m)
    } else {
      classicScoreboard(metrics: m)
    }
  }

  private func classicScoreboard(metrics m: Metrics) -> some View {
    ScrollView(.horizontal, showsIndicators: true) {
      VStack(alignment: .leading, spacing: m.stackSpacing) {
        ForEach(Array(players.enumerated()), id: \.offset) { index, player in
          playerRow(player: player, index: index, metrics: m)
        }
      }
      .padding(.horizontal, 6 * scale)
    }
    .frame(maxHeight: m.maxHeight)
  }

  private func partyScoreboard(metrics m: Metrics) -> some View {
    let ranked = Array(players.enumerated()).sorted { $0.element.displayTotal > $1.element.displayTotal }
    return ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .leading, spacing: m.rowSpacing) {
        ForEach(Array(ranked.enumerated()), id: \.element.offset) { rank, item in
          partyPlayerRow(
            player: item.element,
            index: item.offset,
            rank: rank + 1,
            metrics: m
          )
        }
      }
      .padding(.horizontal, 6 * scale)
    }
    .frame(maxHeight: min(m.maxHeight * 1.35, 520 * scale))
  }

  private func partyPlayerRow(
    player: BowlingGameLogic.Player,
    index: Int,
    rank: Int,
    metrics m: Metrics
  ) -> some View {
    let active = index == currentPlayerIndex
    return VStack(alignment: .leading, spacing: 6 * scale) {
      HStack(spacing: 8 * scale) {
        Text("#\(rank)")
          .font(.system(size: m.numSize, weight: .heavy, design: .monospaced))
          .foregroundStyle(rank <= 3 ? NeonTheme.neonYellow : .white.opacity(0.45))
          .frame(width: 28 * scale, alignment: .leading)
        Text(player.name.uppercased())
          .font(.system(size: m.nameSize * 0.92, weight: .heavy, design: .monospaced))
          .foregroundStyle(active ? NeonTheme.neonYellow : .white.opacity(0.8))
          .lineLimit(1)
        Spacer(minLength: 4)
        Text("\(player.displayTotal)")
          .font(.system(size: m.totalSize, weight: .black, design: .rounded))
          .foregroundStyle(NeonTheme.neonCyan)
      }
      if active {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: m.frameSpacing) {
            ForEach(0..<10, id: \.self) { frameIndex in
              frameCell(
                frame: player.frames[frameIndex],
                frameIndex: frameIndex,
                active: frameIndex + 1 == currentFrame,
                metrics: m
              )
            }
          }
        }
      } else {
        Text(partyRollsSummary(player))
          .font(.system(size: m.rollSize, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.5))
      }
    }
    .padding(m.rowPadding * 0.85)
    .background(Color.white.opacity(active ? 0.14 : 0.05))
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(active ? NeonTheme.neonYellow.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
    )
  }

  private func partyRollsSummary(_ player: BowlingGameLogic.Player) -> String {
    let rolls = player.frames.flatMap(\.rolls)
    guard !rolls.isEmpty else { return "Jeszcze nie rzucał" }
    let last = rolls.suffix(4).map(String.init).joined(separator: " · ")
    return "Ostatnie: \(last)"
  }

  private func playerRow(player: BowlingGameLogic.Player, index: Int, metrics m: Metrics) -> some View {
    let active = index == currentPlayerIndex
    return VStack(alignment: .leading, spacing: m.rowSpacing) {
      HStack {
        Text(player.name.uppercased())
          .font(.system(size: m.nameSize, weight: .heavy, design: .monospaced))
          .foregroundStyle(active ? NeonTheme.neonYellow : .white.opacity(0.75))
        Spacer()
        Text("\(player.displayTotal)")
          .font(.system(size: m.totalSize, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonCyan)
      }

      HStack(spacing: m.frameSpacing) {
        ForEach(0..<10, id: \.self) { frameIndex in
          frameCell(
            frame: player.frames[frameIndex],
            frameIndex: frameIndex,
            active: active && frameIndex + 1 == currentFrame,
            metrics: m
          )
        }
      }
    }
    .padding(m.rowPadding)
    .background(Color.white.opacity(active ? 0.12 : 0.06))
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(active ? NeonTheme.neonYellow.opacity(0.65) : Color.white.opacity(0.15), lineWidth: 1)
    )
  }

  private func frameCell(
    frame: BowlingGameLogic.Frame,
    frameIndex: Int,
    active: Bool,
    metrics m: Metrics
  ) -> some View {
    VStack(spacing: 3 * scale) {
      Text("\(frameIndex + 1)")
        .font(.system(size: m.numSize, weight: .bold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.45))
      Text(rollsLabel(frame))
        .font(.system(size: m.rollSize, weight: .bold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.9))
        .lineLimit(1)
        .minimumScaleFactor(0.65)
      Text(frameScoreLabel(frame))
        .font(.system(size: m.scoreSize, weight: .heavy, design: .monospaced))
        .foregroundStyle(active ? NeonTheme.neonMagenta : NeonTheme.neonCyan.opacity(0.85))
    }
    .frame(width: m.cellWidth)
    .padding(.vertical, m.cellVPad)
    .background(Color.black.opacity(active ? 0.5 : 0.35))
    .overlay(
      RoundedRectangle(cornerRadius: 2)
        .stroke(active ? NeonTheme.neonMagenta.opacity(0.5) : Color.clear, lineWidth: 1)
    )
  }

  private func frameScoreLabel(_ frame: BowlingGameLogic.Frame) -> String {
    if let score = frame.score { return String(score) }
    guard !frame.rolls.isEmpty else { return "·" }
    return String(frame.rolls.reduce(0, +))
  }

  private func rollsLabel(_ frame: BowlingGameLogic.Frame) -> String {
    if frame.rolls.isEmpty { return "–" }
    if frameIndexIsTenth(frame) {
      return frame.rolls.map(String.init).joined(separator: " ")
    }
    if frame.isStrike { return "X" }
    if frame.rolls.count == 1 { return "\(frame.rolls[0])" }
    if frame.isSpare { return "\(frame.rolls[0]) /" }
    return "\(frame.rolls[0]) \(frame.rolls[1])"
  }

  private func frameIndexIsTenth(_ frame: BowlingGameLogic.Frame) -> Bool {
    frame.rolls.count >= 3 || (frame.rolls.count == 2 && frame.rolls[0] == 10)
  }
}

/// Kompaktowy pasek wyników podczas gry (bez pełnej tabeli 10 frame'ów).
struct BowlingCompactScoreStrip: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: BowlingGame.HUD

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    if hud.players.count > 6 {
      partyStrip
    } else {
      classicStrip
    }
  }

  private var classicStrip: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(Array(hud.players.enumerated()), id: \.offset) { index, player in
          compactChip(player: player, index: index, active: index == hud.currentPlayerIndex)
        }
      }
      .padding(.horizontal, 4)
    }
    .frame(maxHeight: 52)
  }

  private var partyStrip: some View {
    let current = hud.players[hud.currentPlayerIndex]
    let others = Array(hud.players.enumerated())
      .filter { $0.offset != hud.currentPlayerIndex }
      .sorted { $0.element.displayTotal > $1.element.displayTotal }
      .prefix(8)
    return HStack(spacing: 8) {
      compactChip(player: current, index: hud.currentPlayerIndex, active: true, enlarged: true)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 6) {
          ForEach(Array(others.enumerated()), id: \.element.offset) { _, item in
            compactChip(player: item.element, index: item.offset, active: false, enlarged: false)
          }
        }
      }
    }
    .padding(.horizontal, 4)
    .frame(maxHeight: 58)
  }

  private func compactChip(
    player: BowlingGameLogic.Player,
    index: Int,
    active: Bool,
    enlarged: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(player.name.uppercased())
        .font(.system(size: enlarged ? 11 : 9, weight: .heavy, design: .monospaced))
        .foregroundStyle(active ? NeonTheme.neonYellow : .white.opacity(0.55))
        .lineLimit(1)
      Text("\(player.displayTotal)")
        .font(.system(size: enlarged ? 20 : 15, weight: .black, design: .rounded))
        .foregroundStyle(active ? NeonTheme.neonCyan : .white.opacity(0.85))
    }
    .padding(.horizontal, enlarged ? 12 : 8)
    .padding(.vertical, enlarged ? 7 : 5)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.black.opacity(active ? 0.58 : 0.32))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(active ? NeonTheme.neonYellow.opacity(0.55) : Color.white.opacity(0.1), lineWidth: 1)
        )
    )
  }
}

/// Pełnoekranowa tabela — krótko między turami graczy.
struct BowlingFullscreenScoreboardOverlay: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: BowlingGame.HUD
  /// Przechowuje wartość `onConfirmTurnStart` wykorzystywaną przez dany komponent.
  var onConfirmTurnStart: () -> Void = {}

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    GeometryReader { geo in
      let fitScale = min(1.15, geo.size.width / 340, geo.size.height / 520)
      ZStack {
        Color.black.opacity(0.94)
          .ignoresSafeArea()

        VStack(spacing: 14) {
          if hud.gameOver, let winner = hud.winnerName {
            BowlingPodiumHeader(players: hud.players, winnerName: winner, scale: fitScale)
          } else if let announcement = hud.turnAnnouncement {
            Text("NASTĘPNA TURA")
              .font(.system(size: 12, weight: .heavy, design: .monospaced))
              .foregroundStyle(NeonTheme.neonMagenta)
            Text(announcement.uppercased())
              .font(.system(size: 28, weight: .black, design: .rounded))
              .foregroundStyle(NeonTheme.neonYellow)
          }

          Text("TABELA WYNIKÓW")
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundStyle(Color.orange.opacity(0.9))

          BowlingScoreboardView(
            players: hud.players,
            currentPlayerIndex: hud.currentPlayerIndex,
            currentFrame: hud.currentFrame,
            style: .phonePilot,
            scale: fitScale
          )
          .frame(maxHeight: geo.size.height * 0.55)

          if hud.awaitingTurnStart {
            TrikiTurnConfirmBanner(playerName: hud.turnAnnouncement ?? hud.players[hud.currentPlayerIndex].name)
              .onTapGesture(perform: onConfirmTurnStart)
            Text("Przycisk Triki · albo dotknij baneru")
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(.white.opacity(0.55))
          } else if !hud.gameOver {
            Text("Za chwilę wrócisz do rzutu…")
              .font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.white.opacity(0.45))
          }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .ignoresSafeArea()
    .transition(.opacity.combined(with: .scale(scale: 0.98)))
    .zIndex(20)
  }
}

/// Opisuje struct `BowlingHUDOverlay` używany przez warstwę UI i logikę gry.
struct BowlingHUDOverlay: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: BowlingGame.HUD
  /// Przechowuje wartość `onConfirmTurnStart` wykorzystywaną przez dany komponent.
  var onConfirmTurnStart: () -> Void = {}

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        if !hud.showScoreboardInterstitial {
          BowlingCompactScoreStrip(hud: hud)
            .padding(.horizontal, 10)
            .padding(.top, 6)
        }

        Spacer()

        if hud.gameOver, let winner = hud.winnerName, !hud.showScoreboardInterstitial {
        VStack(spacing: 6) {
          Text("KONIEC GRY")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonYellow)
          Text("Zwycięzca: \(winner)")
            .font(.system(size: 16, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
        }
        .padding(16)
        .background(Color.black.opacity(0.65))
        .padding(.bottom, 24)
      } else {
        VStack(spacing: 6) {
          if hud.awaitingTurnStart, let announcement = hud.turnAnnouncement {
            TrikiTurnConfirmBanner(playerName: announcement)
              .padding(.bottom, 4)
              .onTapGesture(perform: onConfirmTurnStart)
            Text("Przycisk Triki · albo dotknij baneru")
              .font(.system(size: 10, weight: .semibold, design: .rounded))
              .foregroundStyle(.white.opacity(0.5))
          } else if let announcement = hud.turnAnnouncement {
            Text("TURA · \(announcement)")
              .font(.system(size: 12, weight: .heavy, design: .monospaced))
              .foregroundStyle(NeonTheme.neonMagenta)
          }
          Text(hud.throwLabel.uppercased())
            .font(.system(size: hud.setupSecondsLeft > 0 ? 26 : 22, weight: .heavy, design: .monospaced))
            .foregroundStyle(hud.setupSecondsLeft > 0 ? Color.orange : (hud.throwPhase == .ready ? NeonTheme.neonYellow : NeonTheme.neonCyan))
          if hud.setupSecondsLeft > 0 {
            Text("Stań spokojnie · rzut za chwilę")
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(.white.opacity(0.6))
          }
          Text("Frame \(hud.currentFrame) · \(currentPlayerName(hud))")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(Color.black.opacity(0.55))
        .padding(.bottom, 20)
      }
      }

      if hud.showScoreboardInterstitial {
        BowlingFullscreenScoreboardOverlay(hud: hud, onConfirmTurnStart: onConfirmTurnStart)
      }

      if let celebration = hud.throwCelebration {
        BowlingPixelCelebrationOverlay(celebration: celebration)
          .transition(.opacity.combined(with: .scale(scale: 1.08)))
          .zIndex(30)
      }
    }
    .animation(.easeInOut(duration: 0.28), value: hud.showScoreboardInterstitial)
    .animation(.spring(response: 0.38, dampingFraction: 0.72), value: hud.throwCelebration)
  }

  private func currentPlayerName(_ hud: BowlingGame.HUD) -> String {
    guard hud.players.indices.contains(hud.currentPlayerIndex) else { return "—" }
    return hud.players[hud.currentPlayerIndex].name
  }
}

/// Opisuje enum `BowlingSceneViewRole` używany przez warstwę UI i logikę gry.
enum BowlingSceneViewRole {
  /// Pełnoekranowy podgląd (telefon lub TV).
  case display
  /// Niewidoczny driver — utrzymuje symulację SceneKit, gdy tor jest tylko na TV.
  case simulationDriver
}

/// Render 3D w niskiej rozdzielczości + powiększenie nearest-neighbor = efekt pixel.
struct PixelatedBowlingSceneView: View {
  /// Przechowuje wartość `scene` wykorzystywaną przez dany komponent.
  let scene: BowlingGameScene
  /// Przechowuje wartość `pixelScale` wykorzystywaną przez dany komponent.
  var pixelScale: CGFloat = 3

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    GeometryReader { geo in
      let w = max(1, geo.size.width)
      let h = max(1, geo.size.height)
      BowlingSceneView(scene: scene, role: .display)
        .frame(width: w / pixelScale, height: h / pixelScale)
        .scaleEffect(pixelScale, anchor: .topLeading)
        .frame(width: w, height: h, alignment: .topLeading)
        .clipped()
    }
  }
}

/// Opisuje struct `BowlingSceneView` używany przez warstwę UI i logikę gry.
struct BowlingSceneView: UIViewRepresentable {
  /// Przechowuje wartość `scene` wykorzystywaną przez dany komponent.
  let scene: BowlingGameScene
  /// Przechowuje wartość `role` wykorzystywaną przez dany komponent.
  var role: BowlingSceneViewRole = .display

  /// Wykonuje operację `makeCoordinator` w bieżącym kontekście gry/UI.
  func makeCoordinator() -> Coordinator {
    Coordinator(scene: scene)
  }

  /// Wykonuje operację `makeUIView` w bieżącym kontekście gry/UI.
  func makeUIView(context: Context) -> SCNView {
    let view = SCNView(frame: .zero)
    context.coordinator.bind(view)
    return view
  }

  /// Wykonuje operację `updateUIView` w bieżącym kontekście gry/UI.
  func updateUIView(_ uiView: SCNView, context: Context) {
    context.coordinator.bind(uiView)
  }

  static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
    coordinator.unbind(uiView)
  }

  /// Opisuje class `Coordinator` używany przez warstwę UI i logikę gry.
  final class Coordinator {
    private let scene: BowlingGameScene
    private weak var boundView: SCNView?

    init(scene: BowlingGameScene) {
      self.scene = scene
    }

    func bind(_ view: SCNView) {
      boundView = view
      if view.scene !== scene {
        view.scene = scene
      }
      scene.isPaused = false
      view.pointOfView = scene.cameraNode
      view.autoenablesDefaultLighting = false
      view.antialiasingMode = .none
      view.preferredFramesPerSecond = 60
      view.rendersContinuously = true
      view.isPlaying = true
      view.loops = false
      view.layer.magnificationFilter = .nearest
      view.layer.minificationFilter = .nearest
      switch view.tag {
      case 0:
        view.tag = 1
        view.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.10, alpha: 1)
      default:
        break
      }
    }

    func unbind(_ view: SCNView) {
      if boundView === view {
        boundView = nil
      }
      view.isPlaying = false
      view.scene = nil
    }
  }
}

// MARK: - TV · Bowling

/// Opisuje struct `BowlingTVLobbyView` używany przez warstwę UI i logikę gry.
struct BowlingTVLobbyView: View {
  @EnvironmentObject private var display: QuizExternalDisplay

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    GeometryReader { geo in
      ZStack {
        bowlingTVBackdrop()
        if !display.isExternalScreenConnected {
          bowlingTVWaiting(
            title: "BOWLING 3D",
            subtitle: "Podłącz telewizor AirPlay lub HDMI",
            footnote: "Na telefonie włącz „Tor na telewizorze” i wybierz TV"
          )
        } else {
          let payload = display.bowlingLobbyPayload
          bowlingTVWaiting(
            title: "BOWLING 3D",
            subtitle: payload.modeTitle,
            footnote: payload.playerNames.isEmpty
              ? "Naciśnij GRAJ na telefonie"
              : payload.playerNames.joined(separator: " · ") + " — GRAJ na telefonie"
          )
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .preferredColorScheme(.dark)
    .ignoresSafeArea()
  }
}

/// Opisuje struct `BowlingTVView` używany przez warstwę UI i logikę gry.
struct BowlingTVView: View {
  @EnvironmentObject private var display: QuizExternalDisplay

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    GeometryReader { geo in
      ZStack {
        bowlingTVBackdrop()
        if !display.isExternalScreenConnected {
          bowlingTVWaiting(
            title: "BOWLING 3D",
            subtitle: "Podłącz telewizor AirPlay lub HDMI",
            footnote: "Włącz „Tor na telewizorze” na telefonie"
          )
        } else if !display.bowlingPayload.isBowlingActive {
          bowlingTVWaiting(
            title: "BOWLING 3D",
            subtitle: "Gotowy do gry!",
            footnote: "Naciśnij GRAJ na telefonie · Triki = celuj i rzuć"
          )
        } else if let scene = display.bowlingScene {
          bowlingTVGameLayer(size: geo.size, scene: scene, hud: display.bowlingPayload.hud)
        } else {
          bowlingTVWaiting(
            title: "BOWLING 3D",
            subtitle: "Ładowanie toru…",
            footnote: "Chwilę poczekaj"
          )
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .preferredColorScheme(.dark)
    .ignoresSafeArea()
  }

  private func bowlingTVGameLayer(size: CGSize, scene: BowlingGameScene, hud: BowlingGame.HUD?) -> some View {
    let scale = max(1.2, min(2.2, size.width / 960))
    return ZStack {
      PixelatedBowlingSceneView(scene: scene, pixelScale: 4)
        .frame(width: size.width, height: size.height)
        .ignoresSafeArea()

      if let hud {
        ZStack {
          VStack(spacing: 0) {
            Spacer()

            if hud.gameOver, let winner = hud.winnerName, !hud.showScoreboardInterstitial {
            VStack(spacing: 8 * scale) {
              Text("KONIEC GRY")
                .font(.system(size: 28 * scale, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.neonYellow)
              Text("Zwycięzca: \(winner)")
                .font(.system(size: 36 * scale, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
            }
            .padding(24 * scale)
            .background(Color.black.opacity(0.72))
            .padding(.bottom, 48 * scale)
          } else {
            VStack(spacing: 10 * scale) {
              if hud.awaitingTurnStart, let announcement = hud.turnAnnouncement {
                TrikiTurnConfirmBanner(playerName: announcement)
                  .scaleEffect(scale * 1.1)
              } else if let announcement = hud.turnAnnouncement {
                Text("TURA · \(announcement.uppercased())")
                  .font(.system(size: 22 * scale, weight: .heavy, design: .monospaced))
                  .foregroundStyle(NeonTheme.neonMagenta)
              }
              Text(hud.throwLabel.uppercased())
                .font(.system(size: 48 * scale, weight: .heavy, design: .monospaced))
                .foregroundStyle(hud.setupSecondsLeft > 0 ? Color.orange : (hud.throwPhase == .ready ? NeonTheme.neonYellow : NeonTheme.neonCyan))
              if hud.setupSecondsLeft > 0 {
                Text("CELuj TRZONKIEM · RZUT ZA \(hud.setupSecondsLeft)s")
                  .font(.system(size: 16 * scale, weight: .heavy, design: .monospaced))
                  .foregroundStyle(NeonTheme.neonYellow.opacity(0.85))
              }
              Text("COFNIJ → DO PRZODU = RZUT")
                .font(.system(size: 16 * scale, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.neonYellow.opacity(0.75))
                .opacity(hud.setupSecondsLeft > 0 ? 0.35 : 1)
            }
            .padding(.vertical, 20 * scale)
            .padding(.horizontal, 32 * scale)
            .background(Color.black.opacity(0.62))
            .padding(.bottom, 36 * scale)
          }
          }
          .frame(width: size.width, height: size.height)

          if hud.showScoreboardInterstitial {
            BowlingTVFullscreenScoreboardOverlay(hud: hud, scale: scale)
              .frame(width: size.width, height: size.height)
              .transition(.opacity)
          }

          if let celebration = hud.throwCelebration {
            BowlingPixelCelebrationOverlay(celebration: celebration, scale: scale * 1.15)
              .frame(width: size.width, height: size.height)
              .zIndex(40)
          }
        }
        .animation(.easeInOut(duration: 0.28), value: hud.showScoreboardInterstitial)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: hud.throwCelebration)
      }
    }
  }
}

/// Pełnoekranowa tabela na TV — tylko między turami graczy.
struct BowlingTVFullscreenScoreboardOverlay: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: BowlingGame.HUD
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  var scale: CGFloat = 1

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    ZStack {
      Color.black.opacity(0.88)
        .ignoresSafeArea()

      VStack(spacing: 16 * scale) {
        if hud.gameOver, let winner = hud.winnerName {
          BowlingPodiumHeader(players: hud.players, winnerName: winner, scale: scale)
        } else if let announcement = hud.turnAnnouncement {
          Text("NASTĘPNA TURA · \(announcement.uppercased())")
            .font(.system(size: 28 * scale, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonMagenta)
        }

        Text("TABELA WYNIKÓW")
          .font(.system(size: 22 * scale, weight: .heavy, design: .monospaced))
          .foregroundStyle(Color.orange.opacity(0.9))

        BowlingScoreboardView(
          players: hud.players,
          currentPlayerIndex: hud.currentPlayerIndex,
          currentFrame: hud.currentFrame,
          style: .tv,
          scale: scale * 1.1
        )
        .padding(.horizontal, 24 * scale)
      }
      .padding(32 * scale)
    }
  }
}

/// Opisuje struct `BowlingTVScoreboardOverlay` używany przez warstwę UI i logikę gry.
struct BowlingTVScoreboardOverlay: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: BowlingGame.HUD
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  var scale: CGFloat = 1

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    VStack(alignment: .leading, spacing: 10 * scale) {
      Text("TABELA WYNIKÓW")
        .font(.system(size: 20 * scale, weight: .heavy, design: .monospaced))
        .foregroundStyle(Color.orange.opacity(0.9))

      BowlingScoreboardView(
        players: hud.players,
        currentPlayerIndex: hud.currentPlayerIndex,
        currentFrame: hud.currentFrame,
        style: .tv,
        scale: scale
      )
    }
    .padding(14 * scale)
    .background(
      RoundedRectangle(cornerRadius: 10 * scale)
        .fill(Color.black.opacity(0.78))
        .overlay(
          RoundedRectangle(cornerRadius: 10 * scale)
            .stroke(Color.orange.opacity(0.35), lineWidth: 2)
        )
    )
  }
}

private func bowlingTVBackdrop() -> some View {
  ZStack {
    Color(red: 0.03, green: 0.04, blue: 0.10)
    RadialGradient(
      colors: [Color.orange.opacity(0.12), NeonTheme.neonCyan.opacity(0.06), .clear],
      center: .center,
      startRadius: 40,
      endRadius: 700
    )
  }
  .ignoresSafeArea()
}

// MARK: - Pixel celebrations (Kinect Sports style)

/// Wielki komunikat po rzucie — strike, spare, liczba kręgli (8-bit look).
struct BowlingPixelCelebrationOverlay: View {
  let celebration: BowlingThrowCelebration
  var scale: CGFloat = 1

  @State private var pop = false
  @State private var shake = false
  @State private var pinPulse = false

  private var accent: Color {
    Color(
      red: Double((celebration.accentHex >> 16) & 0xFF) / 255,
      green: Double((celebration.accentHex >> 8) & 0xFF) / 255,
      blue: Double(celebration.accentHex & 0xFF) / 255
    )
  }

  var body: some View {
    ZStack {
      Color.black.opacity(celebration.kind == .gutter ? 0.55 : 0.42)
        .ignoresSafeArea()

      pixelBurst

      VStack(spacing: 18 * scale) {
        Text(celebration.playerName.uppercased())
          .font(.system(size: 14 * scale, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white.opacity(0.65))

        Text(celebration.displayHeadline)
          .font(.system(size: headlineSize, weight: .black, design: .monospaced))
          .tracking(celebrationTracking)
          .foregroundStyle(accent)
          .shadow(color: accent.opacity(0.85), radius: 0, x: 3, y: 3)
          .shadow(color: .black, radius: 0, x: 5, y: 5)
          .scaleEffect(pop ? 1 : 0.35)
          .offset(x: shake ? 6 : 0)

        if showsPinCount {
          HStack(alignment: .lastTextBaseline, spacing: 10 * scale) {
            Text("\(celebration.pinsDown)")
              .font(.system(size: 72 * scale, weight: .black, design: .rounded))
              .foregroundStyle(.white)
              .scaleEffect(pinPulse ? 1.06 : 0.94)
            VStack(alignment: .leading, spacing: 4 * scale) {
              Text("KRĘGLI")
                .font(.system(size: 22 * scale, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent)
              Text("STRĄCONO")
                .font(.system(size: 12 * scale, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.55))
            }
          }
        }

        Text(celebration.subtitle)
          .font(.system(size: 15 * scale, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.8))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24 * scale)
      }
      .padding(28 * scale)
      .background(
        RoundedRectangle(cornerRadius: 8 * scale)
          .fill(Color.black.opacity(0.72))
          .overlay(
            RoundedRectangle(cornerRadius: 8 * scale)
              .stroke(accent.opacity(0.65), lineWidth: 3)
          )
      )
      .padding(.horizontal, 20 * scale)
    }
    .allowsHitTesting(false)
    .onAppear {
      withAnimation(.spring(response: 0.32, dampingFraction: 0.58)) { pop = true }
      if celebration.kind == .strike || celebration.kind == .spare {
        withAnimation(.easeInOut(duration: 0.08).repeatCount(8, autoreverses: true)) { shake = true }
      }
      if showsPinCount {
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { pinPulse = true }
      }
      UIAccessibility.post(notification: .announcement, argument: celebration.displayHeadline)
    }
  }

  private var celebrationTracking: CGFloat {
    switch celebration.kind {
    case .strike: return 6 * scale
    case .spare: return 5 * scale
    default: return 1 * scale
    }
  }

  private var headlineSize: CGFloat {
    switch celebration.kind {
    case .strike, .spare: return 52 * scale
    case .nine: return 36 * scale
    case .gutter: return 32 * scale
    default: return 38 * scale
    }
  }

  private var showsPinCount: Bool {
    switch celebration.kind {
    case .strike, .spare, .gutter: return false
    default: return celebration.pinsDown > 0
    }
  }

  private var pixelBurst: some View {
    GeometryReader { geo in
      let cols = 14
      let rows = 8
      ForEach(0..<(cols * rows), id: \.self) { i in
        let col = i % cols
        let row = i / cols
        let x = geo.size.width * (CGFloat(col) + 0.5) / CGFloat(cols)
        let y = geo.size.height * (CGFloat(row) + 0.35) / CGFloat(rows)
        Rectangle()
          .fill(accent.opacity(pixelAlpha(col: col, row: row)))
          .frame(width: 10 * scale, height: 10 * scale)
          .position(x: x, y: y)
          .opacity(pop ? 1 : 0)
      }
    }
    .allowsHitTesting(false)
  }

  private func pixelAlpha(col: Int, row: Int) -> Double {
    let wave = sin(Double(col) * 0.9 + Double(row) * 0.7)
    return 0.08 + (wave + 1) * 0.06
  }
}

/// Podium TOP 3 przy końcu imprezy.
struct BowlingPodiumHeader: View {
  let players: [BowlingGameLogic.Player]
  let winnerName: String
  var scale: CGFloat = 1

  private var topThree: [(name: String, score: Int)] {
    players
      .map { ($0.name, $0.displayTotal) }
      .sorted { $0.1 > $1.1 }
      .prefix(3)
      .map { ($0.0, $0.1) }
  }

  var body: some View {
    VStack(spacing: 12 * scale) {
      Text("KONIEC IMPREZY")
        .font(.system(size: 18 * scale, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonYellow)
      Text("🏆 \(winnerName.uppercased())")
        .font(.system(size: 28 * scale, weight: .black, design: .monospaced))
        .foregroundStyle(.white)
      HStack(alignment: .bottom, spacing: 10 * scale) {
        podiumSlot(rank: 2, tint: Color.white.opacity(0.55))
        podiumSlot(rank: 1, tint: NeonTheme.neonYellow)
        podiumSlot(rank: 3, tint: NeonTheme.neonMagenta.opacity(0.85))
      }
      .frame(maxWidth: 420 * scale)
    }
  }

  @ViewBuilder
  private func podiumSlot(rank: Int, tint: Color) -> some View {
    let entry = topThree.indices.contains(rank - 1) ? topThree[rank - 1] : nil
    let height: CGFloat = rank == 1 ? 72 : (rank == 2 ? 52 : 44)
    VStack(spacing: 4 * scale) {
      if let entry {
        Text(entry.name.uppercased())
          .font(.system(size: 10 * scale, weight: .heavy, design: .monospaced))
          .foregroundStyle(tint)
          .lineLimit(1)
        Text("\(entry.score)")
          .font(.system(size: rank == 1 ? 22 : 16, weight: .black, design: .rounded))
          .foregroundStyle(.white)
      } else {
        Text("—")
          .font(.system(size: 12 * scale, weight: .bold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.3))
      }
      RoundedRectangle(cornerRadius: 3)
        .fill(tint.opacity(0.35))
        .frame(width: rank == 1 ? 88 : 64, height: height * scale)
        .overlay(
          Text("\(rank)")
            .font(.system(size: 14 * scale, weight: .heavy, design: .monospaced))
            .foregroundStyle(tint)
        )
    }
    .frame(maxWidth: .infinity)
  }
}

private func bowlingTVWaiting(title: String, subtitle: String, footnote: String) -> some View {
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  let scale = max(1.2, min(2.0, UIScreen.main.bounds.width / 960))
  return VStack(spacing: 28 * scale) {
    Spacer()
    Text("🎳")
      .font(.system(size: 56 * scale))
    Text(title)
      .font(.system(size: 72 * scale, weight: .black, design: .rounded))
      .foregroundStyle(Color.orange)
      .neonGlow(Color.orange, radius: 12)
    Text(subtitle)
      .font(.system(size: 36 * scale, weight: .semibold, design: .rounded))
      .foregroundStyle(.white)
    Text(footnote)
      .font(.system(size: 24 * scale, weight: .medium, design: .rounded))
      .foregroundStyle(.white.opacity(0.55))
      .multilineTextAlignment(.center)
      .padding(.horizontal, 40 * scale)
    Spacer()
    Image(systemName: "tv.and.mediabox")
      .font(.system(size: 56 * scale, weight: .light))
      .foregroundStyle(NeonTheme.neonCyan.opacity(0.7))
    Spacer()
  }
  .frame(maxWidth: .infinity)
  .padding(32 * scale)
}
