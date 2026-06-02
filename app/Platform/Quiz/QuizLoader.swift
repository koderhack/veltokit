import Combine
import Foundation
import Translation

/// Pobieranie kategorii i rund po 10 pytań (tłumaczenie PL).
@MainActor
/// Reprezentuje typ `QuizLoader`.
final class QuizLoader: ObservableObject {
  @Published private(set) var categories: [QuizCategory] = []
  @Published private(set) var roundQuestions: [Question] = []
  @Published private(set) var progress: Int = 0
  @Published private(set) var statusMessage = "Przygotowanie…"
  @Published private(set) var isLoadingRound = false
  @Published private(set) var errorMessage: String?

/// Wykonuje operacje `loadCategoriesIfNeeded`.
  func loadCategoriesIfNeeded() async {
    guard categories.isEmpty else { return }
    do {
      categories = try await QuizCategoryService.fetchCategories()
    } catch {
      categories = [QuizCategory.any]
      errorMessage = error.localizedDescription
    }
  }

/// Wykonuje operacje `beginRoundLoad`.
  func beginRoundLoad(categoryName: String) {
    isLoadingRound = true
    errorMessage = nil
    progress = 0
    roundQuestions = []
    statusMessage = "Przygotowuję „\(categoryName)”…"
  }

  /// 10 losowych pytań w wybranej kategorii (+ tłumaczenie).
  func loadRound(
    category: QuizCategory,
    questionCount: Int,
    translationSession: TranslationSession
  ) async {
    isLoadingRound = true
    errorMessage = nil
    progress = 0
    roundQuestions = []
/// Przechowuje wartosc `catID`.
    let catID = category.id

    if questionCount >= QuizRules.questionsPerRound,
/// Przechowuje wartosc `cached`.
       let cached = QuizRoundCache.load(categoryID: catID) {
      roundQuestions = Array(cached.prefix(questionCount))
      progress = 100
      statusMessage = "Wczytano z pamięci"
      isLoadingRound = false
      return
    }

    do {
      statusMessage = "Pobieram pytania…"
      progress = 5
/// Przechowuje wartosc `english`.
      let english = try await OpenTriviaClient.fetchQuestions(
        amount: max(questionCount, QuizRules.questionsPerRound),
        categoryID: catID > 0 ? catID : nil
      )
      progress = 25
      statusMessage = "Tłumaczę…"

/// Przechowuje wartosc `polish`.
      let polish = try await QuizTranslator.translateAll(english, session: translationSession) { [weak self] value in
        self?.progress = 25 + (value * 70) / 100
        self?.statusMessage = "Tłumaczę… \(value)%"
      }

/// Przechowuje wartosc `picked`.
      let picked = Array(polish.shuffled().prefix(questionCount))
      roundQuestions = picked
      if questionCount >= QuizRules.questionsPerRound {
        try? QuizRoundCache.save(Array(polish.prefix(QuizRules.questionsPerRound)), categoryID: catID)
      }
      progress = 100
      statusMessage = "Gotowe (\(picked.count) pytań)"
    } catch {
      errorMessage = error.localizedDescription
      statusMessage = "Błąd"
    }
    isLoadingRound = false
  }
}
