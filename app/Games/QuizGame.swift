import Foundation
import VeltoKit

/// Quiz — logika rundy; UI w `QuizGameView`.
final class QuizGame: Game {
  let name = "Quiz"
  let inputProfile: GameInputProfile = .quiz

  private let questions: [Question]
  private let mode: QuizPlayMode
  private let activePlayerName: String
  private let roundLabel: String
  private let player1Score: Int
  private let player2Score: Int
  var onAnswerRecorded: ((Bool) -> Void)?
  var onRoundComplete: (() -> Void)?

  private var index = 0
  private var roundScore = 0
  private var selected = 0
  private var confirmGate = TrikiButtonConfirmGate()
  private var focusGate = TrikiFocusGate()
  private var smoothedPosX = 0.0
  private var posXSeeded = false
  /// Włącza sterowanie Triki: `posX` = wybór A–D, przycisk = zatwierdzenie.
  var isTrikiInputEnabled = false
  private var feedback: Feedback?
  private var feedbackTimer = 0.0
  private var finished = false

  var showsPixelFlash: Bool { false }

  struct HUD: Equatable {
    var questionIndex: Int
    var questionTotal: Int
    var roundScore: Int
    var player1Score: Int
    var player2Score: Int
    var selected: Int
    var holdProgress: Double
    var holdAnswerIndex: Int?
    var isFinished: Bool
    var feedbackLabel: String?
    var questionText: String
    var answers: [String]
    var activePlayerName: String
    var roundLabel: String
    var mode: QuizPlayMode
  }

  private(set) var currentHUD = HUD(
    questionIndex: 0,
    questionTotal: 0,
    roundScore: 0,
    player1Score: 0,
    player2Score: 0,
    selected: 0,
    holdProgress: 0,
    holdAnswerIndex: nil,
    isFinished: false,
    feedbackLabel: nil,
    questionText: "",
    answers: [],
    activePlayerName: "",
    roundLabel: "",
    mode: .solo
  )

  private enum Feedback {
    case correct
    case wrong
  }

  init(
    questions: [Question],
    mode: QuizPlayMode,
    activePlayerName: String,
    roundLabel: String,
    player1Score: Int,
    player2Score: Int
  ) {
    self.questions = questions
    self.mode = mode
    self.activePlayerName = activePlayerName
    self.roundLabel = roundLabel
    self.player1Score = player1Score
    self.player2Score = player2Score
  }

  func start(context: GameContext) {
    index = 0
    roundScore = 0
    selected = 0
    confirmGate.reset()
    focusGate.reset()
    smoothedPosX = 0
    posXSeeded = false
    feedback = nil
    feedbackTimer = 0
    finished = false
    syncHUD(feedbackLabel: nil)
  }

  func submitAnswer(at index: Int) {
    guard feedback == nil, !finished, index >= 0, index < 4 else { return }
    selected = index
    QuizSFX.answerLockIn()
    confirmAnswer()
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    let dt = min(deltaTime, 0.05)
    guard !questions.isEmpty else {
      finishRound()
      return
    }

    if let feedback {
      feedbackTimer -= dt
      if feedbackTimer <= 0 {
        self.feedback = nil
        index += 1
        if index >= questions.count {
          finishRound()
        } else {
          QuizSFX.nextQuestion()
        }
        syncHUD(feedbackLabel: nil)
      } else {
        syncHUD(feedbackLabel: feedback == .correct ? "DOBRZE" : "ŹLE")
      }
      return
    }

    guard !finished, index < questions.count else {
      syncHUD(feedbackLabel: nil)
      return
    }

    if isTrikiInputEnabled {
      updateTrikiSelection(input: input, deltaTime: dt)

      if confirmGate.consume(input: input, deltaTime: dt) {
        QuizSFX.answerLockIn()
        confirmAnswer()
        syncHUD(feedbackLabel: nil)
        return
      }
    }

    syncHUD(feedbackLabel: nil)
  }

  /// Pochylenie → slot A–D (wygładzone, sąsiednie kroki, debounce).
  private func updateTrikiSelection(input: GameInput, deltaTime: TimeInterval) {
    if !posXSeeded {
      smoothedPosX = input.posX
      posXSeeded = true
    } else {
      let w = TrikiUIConfig.quizPosXSmoothing
      smoothedPosX = smoothedPosX * w + input.posX * (1 - w)
    }

    let rawSlot = TrikiSlotMath.focusedSlot(
      posX: smoothedPosX,
      slots: 4,
      currentFocus: selected,
      neutralEnterBand: TrikiUIConfig.quizNeutralEnterBand,
      neutralExitBand: TrikiUIConfig.quizNeutralExitBand
    )

    let steppedSlot: Int?
    if let rawSlot {
      if abs(rawSlot - selected) <= 1 {
        steppedSlot = rawSlot
      } else {
        steppedSlot = rawSlot > selected ? selected + 1 : selected - 1
      }
    } else {
      steppedSlot = nil
    }

    if let resolved = focusGate.resolve(
      rawIndex: steppedSlot,
      current: selected,
      deltaTime: deltaTime,
      adjacentDwell: TrikiUIConfig.quizFocusSwitchAdjacent,
      jumpDwell: TrikiUIConfig.quizFocusSwitchJump
    ), resolved != selected {
      selected = resolved
      QuizSFX.menuFocus()
    } else if rawSlot == nil {
      focusGate.reset()
    }
  }

  func confirmAnswer() {
    guard feedback == nil, !finished, index < questions.count else { return }
    submitCurrentAnswer()
  }

  func render(context: GameContext) {}

  private func submitCurrentAnswer() {
    guard index < questions.count else { return }
    let q = questions[index]
    let correct = selected == q.correctIndex
    if correct {
      roundScore += 1
      feedback = .correct
      QuizSFX.correct()
    } else {
      feedback = .wrong
      QuizSFX.wrong()
    }
    feedbackTimer = QuizRules.feedbackDuration
    onAnswerRecorded?(correct)
    syncHUD(feedbackLabel: feedback == .correct ? "DOBRZE" : "ŹLE")
  }

  private func finishRound() {
    finished = true
    QuizSFX.roundComplete()
    onRoundComplete?()
    syncHUD(feedbackLabel: nil)
  }

  private func syncHUD(feedbackLabel: String?) {
    let q = (!finished && index < questions.count) ? questions[index] : nil
    let total = questions.count
    currentHUD = HUD(
      questionIndex: finished ? total : min(index + 1, max(1, total)),
      questionTotal: total,
      roundScore: roundScore,
      player1Score: player1Score,
      player2Score: player2Score,
      selected: selected,
      holdProgress: 0,
      holdAnswerIndex: nil,
      isFinished: finished,
      feedbackLabel: feedbackLabel,
      questionText: q?.question ?? "",
      answers: q?.answers ?? [],
      activePlayerName: activePlayerName,
      roundLabel: roundLabel,
      mode: mode
    )
  }
}
