import Foundation

/// Pytanie gotowe do rozgrywki (po tłumaczeniu na PL).
struct Question: Codable, Equatable, Sendable {
/// Przechowuje wartosc `question`.
  let question: String
/// Przechowuje wartosc `answers`.
  let answers: [String]
/// Przechowuje wartosc `correctIndex`.
  let correctIndex: Int

/// Inicjalizuje nowa instancje.
  init(question: String, answers: [String], correctIndex: Int) {
    self.question = question
    self.answers = answers
    self.correctIndex = correctIndex
  }
}
