import SwiftUI
import VeltoKit

/// Opisuje struct `QuizGameView` używany przez warstwę UI i logikę gry.
struct QuizGameView: View {
  @ObservedObject var session: QuizSession
  @ObservedObject var inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay
  @StateObject private var engine: GameEngine
  @State private var linkActive = false
  @State private var uiTick = 0

  /// Inicjalizuje instancję i ustawia wymagane zależności.
  init(session: QuizSession, inputProvider: MotionInputProvider, tuning: GameTuning) {
    self.session = session
    self.inputProvider = inputProvider
    self.tuning = tuning

    let game = QuizGame(
      questions: session.currentRoundQuestions,
      mode: session.mode,
      activePlayerName: session.activePlayerName(),
      roundLabel: session.roundLabel(),
      player1Score: session.player1Score,
      player2Score: session.player2Score
    )
    game.onAnswerRecorded = { correct in
      session.recordAnswer(correct: correct)
    }
    game.onRoundComplete = {
      session.completeRound()
    }
    _engine = StateObject(
      wrappedValue: GameEngine(game: game, inputProvider: inputProvider)
    )
  }

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    GeometryReader { geo in
      let insets = geo.safeAreaInsets
      ZStack {
        Color.black.ignoresSafeArea()
        quizContent(safeTop: insets.top, safeBottom: insets.bottom)
      }
    }
    .background(Color.black)
    .phonePortraitGame()
    .onAppear {
      trikiUI.isSuspended = true
      trikiUI.clear()
      quizDisplay.setQuizActive(true)
      GameManager.applyMotionMode(gameType: .quiz, to: inputProvider)
      engine.quizGame?.onRoundComplete = { [session] in
        session.completeRound()
        dismiss()
      }
      syncTV()
    }
    .onDisappear {
      trikiUI.isSuspended = false
      quizDisplay.setQuizActive(false)
    }
    .onChange(of: engine.quizHUD) { _, _ in
      syncTV()
    }
    .onChange(of: engine.frameIndex) { _, _ in
      if engine.frameIndex % 6 == 0 { syncTV() }
    }
    .gameLoop { now in
      engine.quizGame?.isTrikiInputEnabled = inputProvider.isTrikiControlAvailable
      engine.step(now: now)
      uiTick &+= 1
      if uiTick % 20 == 0 {
        linkActive = inputProvider.isReceiving
      }
    }
  }

  @ViewBuilder
  private func quizContent(safeTop: CGFloat, safeBottom: CGFloat) -> some View {
    VStack(spacing: 0) {
      topBar
        .padding(.top, safeTop + 4)

      ScrollView(showsIndicators: false) {
        VStack(spacing: 14) {
          if let hud = engine.quizHUD {
            if hud.isFinished {
              roundFinishedCard(hud)
            } else {
              questionCard(hud)
              answersSection(hud)
            }
          }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 8)
      }

      bottomHint
        .padding(.bottom, safeBottom + 6)
    }
    .padding(.horizontal, 12)
  }

  private var topBar: some View {
    HStack(spacing: 8) {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background(Color.white.opacity(0.12))
      }
      .buttonStyle(.plain)

      if let hud = engine.quizHUD {
        VStack(alignment: .leading, spacing: 2) {
          Text(hud.roundLabel)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonCyan)
          Text(hud.activePlayerName)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(NeonTheme.neonMagenta)
        }
        Text("\(hud.questionIndex)/\(hud.questionTotal)")
          .font(.system(size: 11, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white.opacity(0.7))
      }

      Spacer()

      if let hud = engine.quizHUD {
        Text("\(hud.player1Score)")
          .font(.system(size: 12, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonYellow)
        if hud.mode == .duo {
          Text(":")
            .foregroundStyle(.white.opacity(0.4))
          Text("\(hud.player2Score)")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonYellow)
        }
      }

      Circle()
        .fill(linkActive ? NeonTheme.neonGreen : Color.red.opacity(0.85))
        .frame(width: 7, height: 7)

      AirPlayRoutePicker(scale: 2.0)
        .airPlayHitTarget(size: 40)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 6)
  }

  private func questionCard(_ hud: QuizGame.HUD) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("PYTANIE · \(hud.roundScore) pkt w rundzie")
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonMagenta.opacity(0.85))

      Text(hud.questionText)
        .font(.system(size: 18, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func answersSection(_ hud: QuizGame.HUD) -> some View {
    let labels = ["A", "B", "C", "D"]
    let trikiActive = inputProvider.isTrikiControlAvailable
    return VStack(spacing: 8) {
      Text(
        trikiActive
          ? "Dotyk = od razu · Triki: obrót + hold lub przycisk"
          : "Dotknij odpowiedź — zatwierdza od razu"
      )
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonCyan.opacity(0.85))
        .frame(maxWidth: .infinity, alignment: .leading)

      ForEach(Array(hud.answers.enumerated()), id: \.offset) { offset, answer in
        let letter = offset < labels.count ? labels[offset] : "?"
        let selected = offset == hud.selected
        Button {
          engine.quizGame?.submitAnswer(at: offset)
        } label: {
          answerRow(letter: letter, text: answer, selected: selected)
        }
        .buttonStyle(.plain)
        .disabled(hud.feedbackLabel != nil)
      }
    }
  }

  private func answerRow(
    letter: String,
    text: String,
    selected: Bool
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        Rectangle()
          .fill(selected ? NeonTheme.neonCyan : Color.white.opacity(0.06))
          .frame(width: 28, height: 44)
        Text(letter)
          .font(.system(size: 13, weight: .heavy, design: .monospaced))
          .foregroundStyle(selected ? .black : .white)
          .frame(width: 28, height: 44)
      }
      .clipShape(RoundedRectangle(cornerRadius: 2))

      Text(text)
        .font(.system(size: 15, weight: selected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(selected ? .white : .white.opacity(0.88))
        .lineSpacing(3)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 6)
    .background(selected ? NeonTheme.neonCyan.opacity(0.1) : Color.clear)
  }

  private func roundFinishedCard(_ hud: QuizGame.HUD) -> some View {
    Text("Koniec rundy · \(hud.roundScore)/\(hud.questionTotal)")
      .font(.system(size: 16, weight: .heavy, design: .monospaced))
      .foregroundStyle(NeonTheme.neonGreen)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
  }

  private func syncTV() {
    quizDisplay.update(hud: engine.quizHUD, session: session)
  }

  private var bottomHint: some View {
    let hud = engine.quizHUD
    let feedback = hud?.feedbackLabel

    return Group {
      if let feedback {
        Text(feedback)
          .font(.system(size: 16, weight: .heavy, design: .monospaced))
          .foregroundStyle(feedback == "DOBRZE" ? NeonTheme.neonGreen : Color.red)
          .frame(maxWidth: .infinity)
      } else {
        Label(
          inputProvider.isTrikiControlAvailable
            ? "Obrót = wybór A–D · hold lub przycisk = OK"
            : "Dotknij odpowiedź",
          systemImage: inputProvider.isTrikiControlAvailable ? "hand.tap.fill" : "hand.tap.fill"
        )
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.65))
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.vertical, 6)
  }
}
