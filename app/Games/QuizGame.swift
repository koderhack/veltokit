import Foundation
import VeltoKit

/// Quiz — logika rundy; UI w `QuizGameView`.
final class QuizGame: Game {
  /// Nazwa gry widoczna w metadanych silnika.
  let name = "Quiz"
  /// Profil wejścia określający czułość i mapowanie dla trybu quizowego.
  let inputProfile: GameInputProfile = .quiz

  private let questions: [Question]
  private let mode: QuizPlayMode
  private let activePlayerName: String
  private let roundLabel: String
  private let player1Score: Int
  private let player2Score: Int
  /// Callback wywoływany po zarejestrowaniu odpowiedzi w bieżącym pytaniu.
  var onAnswerRecorded: ((Bool) -> Void)?
  /// Callback wywoływany po zakończeniu rundy.
  var onRoundComplete: (() -> Void)?

  private var index = 0
  private var roundScore = 0
  private var selected = 0
  private var holdProgress: Double = 0
  private var holdAnswerIndex: Int?
  private var holdTracker = TrikiHoldTracker()
  private var focusGate = TrikiFocusGate()
  private var focusSettleRemaining: TimeInterval = 0
  /// Włącza obsługę Triki focus/hold dla wyboru odpowiedzi.
  var isTrikiInputEnabled = false
  private var feedback: Feedback?
  private var feedbackTimer = 0.0
  private var finished = false

  /// Informuje, czy gra powinna renderować błysk pikselowy (quiz nie używa tego efektu).
  var showsPixelFlash: Bool { false }

  /// Snapshot stanu rundy wykorzystywany przez warstwę SwiftUI.
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

  /// Inicjalizuje instancję i ustawia wymagane zależności.
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

  /// Inicjalizuje nową rundę i synchronizuje początkowy stan HUD.
  func start(context: GameContext) {
    index = 0
    roundScore = 0
    selected = 0
    holdProgress = 0
    holdAnswerIndex = nil
    holdTracker.reset()
    focusGate.reset()
    focusSettleRemaining = 0
    feedback = nil
    feedbackTimer = 0
    finished = false
    syncHUD(feedbackLabel: nil)
  }

  /// Dotyk: natychmiastowe zatwierdzenie odpowiedzi.
  func submitAnswer(at index: Int) {
    guard feedback == nil, !finished, index >= 0, index < 4 else { return }
    selected = index
    QuizSFX.answerLockIn()
    confirmAnswer()
  }

  /// Przetwarza input dla focus/hold, feedbacku i przejść między pytaniami.
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
        holdProgress = 0
        holdAnswerIndex = nil
        holdTracker.reset()
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
      let rawIndex = selectionIndex(for: input.posX)
      if rawIndex == nil {
        focusGate.reset()
        focusSettleRemaining = 0
        holdAnswerIndex = nil
        holdTracker.reset()
        holdProgress = 0
      } else {
        let target = focusGate.resolve(
          rawIndex: rawIndex,
          current: selected,
          deltaTime: dt
        ) ?? selected

        if target != selected {
          selected = target
          QuizSFX.menuFocus()
          focusSettleRemaining = TrikiUIConfig.focusSettleDuration
          holdTracker.reset()
          holdProgress = 0
          holdAnswerIndex = nil
        } else {
          focusSettleRemaining = max(0, focusSettleRemaining - dt)
          if focusSettleRemaining <= 0 {
            if input.primaryAction {
              holdTracker.reset()
              holdProgress = 0
              holdAnswerIndex = nil
              QuizSFX.answerLockIn()
              confirmAnswer()
            } else {
              updateHold(deltaTime: dt, focusIndex: selected)
            }
          }
        }
      }
    }
    syncHUD(feedbackLabel: nil)
  }

  /// Zatwierdza aktualnie wybraną odpowiedź, jeśli runda jest aktywna.
  func confirmAnswer() {
    guard feedback == nil, !finished, index < questions.count else { return }
    submitCurrentAnswer()
  }

  /// Placeholder wymagań protokołu `Game` (quiz renderuje się przez HUD/SwiftUI).
  func render(context: GameContext) {}

  private func selectionIndex(for posX: Double) -> Int? {
    TrikiUIMath.focusedSlot(posX: posX, slots: 4, currentFocus: selected)
  }

  private func updateHold(deltaTime: TimeInterval, focusIndex: Int) {
    if holdAnswerIndex != focusIndex {
      holdAnswerIndex = focusIndex
      holdTracker.reset()
      holdProgress = 0
    }

    if holdTracker.advance(deltaTime: deltaTime, duration: TrikiUIConfig.quizHoldDuration) {
      selected = focusIndex
      holdTracker.reset()
      holdProgress = 0
      holdAnswerIndex = nil
      QuizSFX.answerLockIn()
      QuizSFX.resetHoldTicks()
      confirmAnswer()
    } else {
      holdProgress = holdTracker.progress
      QuizSFX.holdProgress(holdProgress)
    }
  }

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
      holdProgress: min(1, holdProgress),
      holdAnswerIndex: holdAnswerIndex,
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
