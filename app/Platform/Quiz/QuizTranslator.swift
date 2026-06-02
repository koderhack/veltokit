import Foundation
import Translation

/// Tłumaczenie EN → PL (sesja z `.translationTask`).
enum QuizTranslator {
  private static let batchPause: UInt64 = 80_000_000
  private static let stringsPerQuestion = 5

/// Wykonuje operacje `translateAll`.
  static func translateAll(
    _ questions: [Question],
    session: TranslationSession,
    onProgress: @MainActor (Int) -> Void
  ) async throws -> [Question] {
    try await session.prepareTranslation()

/// Przechowuje wartosc `translated`.
    var translated: [Question] = []
    translated.reserveCapacity(questions.count)
/// Przechowuje wartosc `totalStrings`.
    let totalStrings = max(1, questions.count * stringsPerQuestion)
/// Przechowuje wartosc `doneStrings`.
    var doneStrings = 0

    for (index, item) in questions.enumerated() {
/// Przechowuje wartosc `pl`.
      let pl = try await translateQuestion(item, session: session)
      translated.append(pl)
      doneStrings += stringsPerQuestion
/// Przechowuje wartosc `percent`.
      let percent = 10 + Int(Double(doneStrings) / Double(totalStrings) * 90)
      await onProgress(min(99, percent))

      if index % 3 == 2 {
        try await Task.sleep(nanoseconds: batchPause)
      }
    }

    await onProgress(100)
    return translated
  }

  private static func translateQuestion(
    _ item: Question,
    session: TranslationSession
  ) async throws -> Question {
/// Przechowuje wartosc `questionPL`.
    let questionPL = try await translateText(item.question, session: session)
/// Przechowuje wartosc `answersPL`.
    var answersPL: [String] = []
    answersPL.reserveCapacity(item.answers.count)
    for answer in item.answers {
      answersPL.append(try await translateText(answer, session: session))
    }
    return Question(question: questionPL, answers: answersPL, correctIndex: item.correctIndex)
  }

  private static func translateText(_ text: String, session: TranslationSession) async throws -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return text }
    let response = try await session.translate(trimmed)
    return response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
