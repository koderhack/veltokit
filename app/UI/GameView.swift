import SwiftUI
import VeltoKit

enum GameType: String, CaseIterable, Identifiable {
  case pong = "Pong"
  case dart = "Dart"
  case quiz = "Quiz"
  case bowling = "Bowling"

  var id: String { rawValue }

  static let platformGames: [GameType] = [.pong, .dart, .quiz, .bowling]

  var inputProfile: GameInputProfile {
    switch self {
    case .pong: return .pong
    case .dart: return .dart
    case .quiz: return .quiz
    case .bowling: return .bowling
    }
  }

  var usesQuizLoader: Bool { self == .quiz }

  func makeGame() -> any Game {
    switch self {
    case .pong: return PongGame()
    case .dart: return DartGame()
    case .quiz:
      return QuizGame(
        questions: [],
        mode: .solo,
        activePlayerName: "Quiz",
        roundLabel: "—",
        player1Score: 0,
        player2Score: 0
      )
    case .bowling:
      return BowlingGame(playerNames: ["Gracz 1"])
    }
  }
}

struct GameView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  let gameType: GameType
  let inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning
  @StateObject private var engine: GameEngine
  @State private var linkActive = false
  @State private var showHUD = false
  @State private var uiTick = 0

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
    GameScreenLayout(
      commands: engine.drawCommands,
      canvasDisplayMode: .portraitPhone,
      horizontalPadding: 8,
      topExtraPadding: 6
    ) {
      VStack(spacing: 0) {
        phoneOverlayBar
        if showHUD {
          motionDebugHUD
        }
        Spacer(minLength: 0)
      }
    }
    .phonePortraitGame()
    .onAppear {
      trikiUI.isSuspended = true
      trikiUI.clear()
      GameManager.applyMotionMode(gameType: gameType, to: inputProvider)
    }
    .onDisappear {
      trikiUI.isSuspended = false
    }
    .gameLoop { now in
      engine.step(now: now)
      uiTick &+= 1
      if uiTick % 20 == 0 {
        linkActive = inputProvider.isReceiving
      }
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
