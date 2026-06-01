import Combine
import Foundation

enum QuizPlayMode: String, CaseIterable, Identifiable {
  case solo
  case duo

  var id: String { rawValue }

  var title: String {
    switch self {
    case .solo: return "1 gracz"
    case .duo: return "2 graczy"
    }
  }

  var subtitle: String {
    switch self {
    case .solo: return "5 rund × 10 pytań"
    case .duo: return "20 rund · na zmianę"
    }
  }
}

enum QuizFlowPhase: Equatable {
  case lobby
  case categoryPick
  case loadingRound
  case calibration
  case playing
  case finished
}

/// Stan rozgrywki quizu (solo / 2 osoby).
@MainActor
final class QuizSession: ObservableObject {
  @Published var mode: QuizPlayMode = .solo
  @Published var player1Name: String = "Gracz 1"
  @Published var player2Name: String = "Gracz 2"
  @Published var phase: QuizFlowPhase = .lobby
  @Published private(set) var roundIndex: Int = 0
  @Published private(set) var player1Score: Int = 0
  @Published private(set) var player2Score: Int = 0
  @Published var selectedCategory: QuizCategory = .any
  @Published private(set) var activePlayerIndex: Int = 0
  @Published private(set) var categoryPickerIndex: Int = 0
  @Published private(set) var currentRoundQuestions: [Question] = []
  @Published private(set) var questionsPerRound: Int = QuizRules.questionsPerRound
  @Published private(set) var categoryChoices: [QuizCategory] = []

  var totalRounds: Int {
    mode == .solo ? QuizRules.soloRounds : QuizRules.duoRounds
  }

  var isLastRound: Bool { roundIndex >= totalRounds - 1 }

  func resetScores() {
    player1Score = 0
    player2Score = 0
    roundIndex = 0
    activePlayerIndex = 0
    categoryPickerIndex = 0
  }

  func beginCategorySelection(from pool: [QuizCategory]) {
    categoryChoices = Self.pickRandomCategories(from: pool, count: QuizRules.categoryChoicesPerRound)
    phase = .categoryPick
    if mode == .duo {
      categoryPickerIndex = roundIndex % 2
    }
  }

  private static func pickRandomCategories(from pool: [QuizCategory], count: Int) -> [QuizCategory] {
    let available = pool.isEmpty ? [QuizCategory.any] : pool
    guard available.count > count else { return available.shuffled() }
    return Array(available.shuffled().prefix(count))
  }

  func applyLoadedRound(_ questions: [Question]) {
    currentRoundQuestions = questions
    questionsPerRound = questions.count
    if mode == .duo {
      activePlayerIndex = roundIndex % 2
    } else {
      activePlayerIndex = 0
    }
    phase = .playing
  }

  func startPlaying() {
    phase = .playing
  }

  func recordAnswer(correct: Bool) {
    if mode == .solo || activePlayerIndex == 0 {
      if correct { player1Score += 1 }
    } else {
      if correct { player2Score += 1 }
    }
  }

  func completeRound() {
    roundIndex += 1
    phase = roundIndex >= totalRounds ? .finished : .categoryPick
  }

  func activePlayerName() -> String {
    activePlayerIndex == 0 ? trimmed(player1Name, fallback: "Gracz 1") : trimmed(player2Name, fallback: "Gracz 2")
  }

  func categoryPickerName() -> String {
    categoryPickerIndex == 0 ? trimmed(player1Name, fallback: "Gracz 1") : trimmed(player2Name, fallback: "Gracz 2")
  }

  func categoryTargetName() -> String {
    categoryPickerIndex == 0 ? trimmed(player2Name, fallback: "Gracz 2") : trimmed(player1Name, fallback: "Gracz 1")
  }

  func roundLabel() -> String {
    "Runda \(min(roundIndex + 1, totalRounds))/\(totalRounds)"
  }

  func scoreboardLine() -> String {
    let p1 = trimmed(player1Name, fallback: "Gracz 1")
    let p2 = trimmed(player2Name, fallback: "Gracz 2")
    if mode == .solo {
      return "\(p1): \(player1Score) pkt"
    }
    return "\(p1) \(player1Score) · \(p2) \(player2Score)"
  }

  func shareSummary() -> String {
    let p1 = trimmed(player1Name, fallback: "Gracz 1")
    let p2 = trimmed(player2Name, fallback: "Gracz 2")
    if mode == .solo {
      return "Quiz Triki — \(p1): \(player1Score)/\(totalRounds * QuizRules.questionsPerRound) pkt"
    }
    return "Quiz Triki — \(p1) \(player1Score) : \(player2Score) \(p2)"
  }

  private func trimmed(_ text: String, fallback: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty ? fallback : t
  }
}
