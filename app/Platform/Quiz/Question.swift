import Foundation

/// Pytanie gotowe do rozgrywki (po tłumaczeniu na PL).
struct Question: Codable, Equatable, Sendable {
  let question: String
  let answers: [String]
  let correctIndex: Int

  init(question: String, answers: [String], correctIndex: Int) {
    self.question = question
    self.answers = answers
    self.correctIndex = correctIndex
  }
}
