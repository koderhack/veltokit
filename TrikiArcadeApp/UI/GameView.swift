import SwiftUI
import TrikiMotionKit

enum GameType: String, CaseIterable, Identifiable {
  case pong = "Pong"
  case dart = "Dart"
  case breakout = "Breakout"
  case catchGame = "Catch"
  case reaction = "Reaction"
  case reflexShot = "Reflex Shot"

  var id: String { rawValue }

  /// Główne gry platformy (menu).
  static let platformGames: [GameType] = [.pong, .dart]

  var inputProfile: GameInputProfile {
    switch self {
    case .pong, .breakout: return .pong
    case .dart, .reflexShot: return .dart
    case .catchGame: return .catchGame
    case .reaction: return .reactionTilt
    }
  }

  func makeGame() -> any Game {
    switch self {
    case .pong: return PongGame()
    case .dart: return DartGame()
    case .breakout: return BreakoutGame()
    case .catchGame: return CatchGame()
    case .reaction: return ReactionTiltGame()
    case .reflexShot: return ReflexShotGame()
    }
  }
}

struct GameView: View {
  @Environment(\.dismiss) private var dismiss

  let gameType: GameType
  let inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning
  @StateObject private var engine: GameEngine
  @State private var linkActive = false
  @State private var showHUD = true

  init(gameType: GameType, inputProvider: MotionInputProvider, tuning: GameTuning) {
    self.gameType = gameType
    self.inputProvider = inputProvider
    self.tuning = tuning
    _engine = StateObject(
      wrappedValue: GameEngine(
        game: gameType.makeGame(),
        inputProvider: inputProvider
      )
    )
  }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        Color.black.ignoresSafeArea()

        PixelCanvas(
          commands: engine.drawCommands,
          gridWidth: GameContext.width,
          gridHeight: GameContext.height,
          frameIndex: engine.frameIndex,
          displayMode: .portraitPhone
        )
        .frame(width: geo.size.width, height: geo.size.height)

        VStack(spacing: 0) {
          phoneOverlayBar
          if showHUD {
            motionDebugHUD
          }
          Spacer(minLength: 0)
        }
        .safeAreaPadding(.horizontal, 8)
        .safeAreaPadding(.top, 4)
      }
    }
    .ignoresSafeArea()
    .phonePortraitGame()
    .onAppear {
      GameManager.applyMotionMode(gameType: gameType, to: inputProvider)
    }
    .gameLoop { now in
      engine.step(now: now)
      linkActive = inputProvider.isReceiving
    }
  }

  private var phoneOverlayBar: some View {
    HStack(spacing: 10) {
      Button(action: { dismiss() }) {
        Label("Wyjście", systemImage: "xmark")
          .font(.system(size: 11, weight: .heavy, design: .monospaced))
          .labelStyle(.iconOnly)
          .foregroundStyle(.white)
          .padding(8)
          .background(Color.white.opacity(0.12))
      }

      Text(gameType.rawValue.uppercased())
        .font(.system(size: 11, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))

      Spacer()

      Circle()
        .fill(linkActive ? Color.green : Color.red)
        .frame(width: 8, height: 8)

      Button {
        showHUD.toggle()
      } label: {
        Image(systemName: showHUD ? "eye.slash" : "eye")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(.cyan)
          .padding(8)
      }
    }
  }

  private var motionDebugHUD: some View {
    let input = engine.hudInput
    let dbg = inputProvider.motionSDK.debug
    let dirColor: Color = {
      if dbg.paddleDirection.contains("LEWO") { return .orange }
      if dbg.paddleDirection.contains("PRAWO") { return .green }
      return .cyan
    }()
    return VStack(alignment: .leading, spacing: 4) {
      Text(dbg.paddleDirection)
        .font(.system(size: 12, weight: .heavy, design: .monospaced))
        .foregroundStyle(dirColor)
      HStack(spacing: 6) {
        hudPill("RAW", dbg.rawX)
        hudPill("OFF", dbg.biasX)
        hudPill("IN", dbg.paddleInput)
      }
      HStack(spacing: 6) {
        hudPill("pos", input.posX)
        hudPill("gz", dbg.paddleGyroZ)
      }
      Text("Logi: Xcode → Console, filtr „Paddle”")
        .font(.system(size: 8, design: .monospaced))
        .foregroundStyle(.white.opacity(0.45))
    }
    .font(.system(size: 10, weight: .bold, design: .monospaced))
    .foregroundStyle(.white)
    .padding(8)
    .background(Color.black.opacity(0.55))
  }

  private func hudPill(_ label: String, _ value: Double) -> some View {
    Text("\(label) \(String(format: "%+.2f", value))")
      .padding(.horizontal, 4)
      .padding(.vertical, 2)
      .background(Color.white.opacity(0.08))
  }
}
