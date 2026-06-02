import Foundation

/// Cache przetłumaczonych rund (kategoria + pytania).
enum QuizRoundCache {
  private static func fileURL(categoryID: Int) -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return base.appendingPathComponent("quiz_round_\(categoryID).json")
  }

/// Wykonuje operacje `load`.
  static func load(categoryID: Int) -> [Question]? {
    let url = fileURL(categoryID: categoryID)
    guard let data = try? Data(contentsOf: url),
          let questions = try? JSONDecoder().decode([Question].self, from: data),
          questions.count >= QuizRules.questionsPerRound else { return nil }
    return questions
  }

/// Wykonuje operacje `save`.
  static func save(_ questions: [Question], categoryID: Int) throws {
    let url = fileURL(categoryID: categoryID)
    let dir = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try JSONEncoder().encode(questions).write(to: url, options: .atomic)
  }
}
