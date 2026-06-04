import SwiftUI
import VeltoKit

/// Quiz — telefon jako pilot; pytania na TV (AirPlay).
struct QuizGameView: View {
  @ObservedObject var session: QuizSession
  @ObservedObject var inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay
  @StateObject private var engine: GameEngine
  @State private var uiTick = 0

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

  var body: some View {
    GeometryReader { geo in
      let insets = geo.safeAreaInsets
      ZStack {
        Color.black.ignoresSafeArea()
        quizContent(safeTop: insets.top, safeBottom: insets.bottom)

        if let label = engine.quizHUD?.feedbackLabel {
          feedbackOverlay(label)
        }
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
    .onChange(of: engine.quizHUD) { _, _ in syncTV() }
    .onChange(of: engine.frameIndex) { _, _ in
      if engine.frameIndex % 6 == 0 { syncTV() }
    }
    .gameLoop { now in
      engine.quizGame?.isTrikiInputEnabled = inputProvider.isTrikiControlAvailable
      engine.step(now: now)
      uiTick &+= 1
    }
  }

  @ViewBuilder
  private func quizContent(safeTop: CGFloat, safeBottom: CGFloat) -> some View {
    VStack(spacing: 0) {
      topBar
        .padding(.top, safeTop + 4)

      if let hud = engine.quizHUD, !hud.isFinished {
        questionProgress(hud)
          .padding(.horizontal, 4)
          .padding(.top, 6)
      }

      ScrollView(showsIndicators: false) {
        VStack(spacing: 16) {
          if let hud = engine.quizHUD {
            if hud.isFinished {
              roundFinishedCard(hud)
            } else {
              questionCard(hud)
              if inputProvider.isTrikiControlAvailable {
                slotPicker(hud.selected)
              }
              answersSection(hud)
            }
          }
        }
        .padding(.horizontal, 4)
        .padding(.top, 10)
        .padding(.bottom, 12)
      }

      bottomHint
        .padding(.bottom, safeBottom + 8)
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
      }

      Spacer()

      if let hud = engine.quizHUD {
        HStack(spacing: 4) {
          Text("\(hud.player1Score)")
            .foregroundStyle(NeonTheme.neonYellow)
          if hud.mode == .duo {
            Text(":").foregroundStyle(.white.opacity(0.35))
            Text("\(hud.player2Score)")
              .foregroundStyle(NeonTheme.neonYellow)
          }
        }
        .font(.system(size: 12, weight: .heavy, design: .monospaced))
      }

      Circle()
        .fill(inputProvider.linkIndicatorColor)
        .frame(width: 8, height: 8)

      AirPlayRoutePicker(scale: 2.0)
        .airPlayHitTarget(size: 40)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 6)
  }

  private func questionProgress(_ hud: QuizGame.HUD) -> some View {
    let total = max(1, hud.questionTotal)
    let progress = Double(hud.questionIndex) / Double(total)
    return VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text("PYTANIE \(hud.questionIndex)/\(hud.questionTotal)")
          .font(.system(size: 9, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white.opacity(0.55))
        Spacer()
        Text("\(hud.roundScore) pkt")
          .font(.system(size: 9, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonYellow.opacity(0.9))
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.1))
          Capsule()
            .fill(
              LinearGradient(
                colors: [NeonTheme.neonMagenta, NeonTheme.neonCyan],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(4, geo.size.width * progress))
        }
      }
      .frame(height: 4)
    }
  }

  private func questionCard(_ hud: QuizGame.HUD) -> some View {
    Text(hud.questionText)
      .font(.system(size: 19, weight: .semibold, design: .rounded))
      .foregroundStyle(.white)
      .lineSpacing(5)
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(Color.white.opacity(0.05))
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(NeonTheme.neonMagenta.opacity(0.35), lineWidth: 1)
      )
  }

  private func slotPicker(_ selected: Int) -> some View {
    let labels = ["A", "B", "C", "D"]
    return HStack(spacing: 8) {
      ForEach(0..<4, id: \.self) { index in
        let active = index == selected
        Text(labels[index])
          .font(.system(size: 13, weight: .heavy, design: .monospaced))
          .foregroundStyle(active ? .black : .white.opacity(0.5))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(active ? NeonTheme.neonCyan : Color.white.opacity(0.06))
          .clipShape(RoundedRectangle(cornerRadius: 4))
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(active ? NeonTheme.neonCyan : Color.clear, lineWidth: 2)
          )
          .animation(.easeOut(duration: 0.18), value: selected)
      }
    }
  }

  private func answersSection(_ hud: QuizGame.HUD) -> some View {
    let labels = ["A", "B", "C", "D"]
    let trikiActive = inputProvider.isTrikiControlAvailable
    let answeringLocked = hud.feedbackLabel != nil

    return VStack(spacing: 10) {
      if trikiActive {
        HStack(spacing: 6) {
          Image(systemName: "arrow.left.and.right")
            .foregroundStyle(NeonTheme.neonCyan)
          Text("Obrót = wybór")
            .foregroundStyle(NeonTheme.neonCyan)
          Image(systemName: "button.programmable")
            .foregroundStyle(NeonTheme.neonMagenta)
          Text("= OK")
            .foregroundStyle(NeonTheme.neonMagenta)
          Spacer()
        }
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
      }

      ForEach(Array(hud.answers.enumerated()), id: \.offset) { offset, answer in
        let letter = offset < labels.count ? labels[offset] : "?"
        let selected = offset == hud.selected
        Button {
          engine.quizGame?.submitAnswer(at: offset)
        } label: {
          QuizAnswerRow(letter: letter, text: answer, selected: selected, trikiActive: trikiActive)
        }
        .buttonStyle(.plain)
        .disabled(answeringLocked)
      }
    }
  }

  private func roundFinishedCard(_ hud: QuizGame.HUD) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "flag.checkered")
        .font(.system(size: 36))
        .foregroundStyle(NeonTheme.neonGreen)
      Text("Koniec rundy")
        .font(.system(size: 18, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white)
      Text("\(hud.roundScore)/\(hud.questionTotal) poprawnych")
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(NeonTheme.neonGreen)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }

  @ViewBuilder
  private func feedbackOverlay(_ label: String) -> some View {
    let correct = label == "DOBRZE"
    VStack {
      Spacer()
      HStack(spacing: 10) {
        Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
          .font(.system(size: 22, weight: .bold))
        Text(label)
          .font(.system(size: 18, weight: .heavy, design: .monospaced))
      }
      .foregroundStyle(correct ? NeonTheme.neonGreen : Color.red)
      .padding(.horizontal, 24)
      .padding(.vertical, 14)
      .background(Color.black.opacity(0.92))
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke((correct ? NeonTheme.neonGreen : Color.red).opacity(0.6), lineWidth: 2)
      )
      .padding(.bottom, 48)
    }
    .transition(.move(edge: .bottom).combined(with: .opacity))
    .animation(.easeOut(duration: 0.2), value: label)
  }

  private func syncTV() {
    quizDisplay.update(hud: engine.quizHUD, session: session)
  }

  private var bottomHint: some View {
    Group {
      if engine.quizHUD?.feedbackLabel == nil {
        if inputProvider.isTrikiControlAvailable {
          Label("Pilot Triki · wybierz i naciśnij przycisk", systemImage: "gamecontroller.fill")
        } else {
          Label("Dotknij odpowiedź na telefonie", systemImage: "hand.tap.fill")
        }
      } else {
        Text("Następne pytanie…")
          .foregroundStyle(.white.opacity(0.45))
      }
    }
    .font(.system(size: 11, weight: .semibold, design: .monospaced))
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }
}

// MARK: - Wiersz odpowiedzi

private struct QuizAnswerRow: View {
  let letter: String
  let text: String
  let selected: Bool
  let trikiActive: Bool

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 4)
          .fill(selected ? NeonTheme.neonCyan : Color.white.opacity(0.08))
          .frame(width: 32, height: 32)
        Text(letter)
          .font(.system(size: 14, weight: .heavy, design: .monospaced))
          .foregroundStyle(selected ? .black : .white.opacity(0.85))
      }

      Text(text)
        .font(.system(size: 15, weight: selected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(selected ? .white : .white.opacity(0.82))
        .lineSpacing(3)
        .frame(maxWidth: .infinity, alignment: .leading)

      if selected, trikiActive {
        Image(systemName: "button.programmable")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(NeonTheme.neonMagenta)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(selected ? NeonTheme.neonCyan.opacity(0.12) : Color.white.opacity(0.03))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(
          selected ? NeonTheme.neonCyan.opacity(0.75) : Color.white.opacity(0.08),
          lineWidth: selected ? 2 : 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .animation(.easeOut(duration: 0.18), value: selected)
  }
}
