import Foundation
import UIKit

/// Pobieranie pytań z Open Trivia DB (angielski, multiple choice).
enum OpenTriviaClient {
  private static let baseURL = "https://opentdb.com/api.php"

/// Reprezentuje typ `FetchError`.
  enum FetchError: LocalizedError {
    case badStatus(Int)
    case apiCode(Int)
    case emptyResults
    case decodeFailed

/// Przechowuje wartosc `errorDescription`.
    var errorDescription: String? {
      switch self {
      case .badStatus(let code): return "HTTP \(code)"
      case .apiCode(let code): return "OpenTDB code \(code)"
      case .emptyResults: return "Brak pytań w odpowiedzi API"
      case .decodeFailed: return "Nie udało się odczytać JSON"
      }
    }
  }

  /// Losowe pytania; `categoryID` nil lub 0 = dowolna kategoria.
  static func fetchQuestions(amount: Int, categoryID: Int? = nil) async throws -> [Question] {
    guard amount > 0 else { throw FetchError.emptyResults }
    var components = URLComponents(string: baseURL)!
    var items = [
      URLQueryItem(name: "amount", value: String(min(50, amount))),
      URLQueryItem(name: "type", value: "multiple"),
    ]
    if let categoryID, categoryID > 0 {
      items.append(URLQueryItem(name: "category", value: String(categoryID)))
    }
    components.queryItems = items
    guard let url = components.url else { throw FetchError.decodeFailed }

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse else { throw FetchError.decodeFailed }
    guard (200..<300).contains(http.statusCode) else {
      throw FetchError.badStatus(http.statusCode)
    }

    let decoded = try JSONDecoder().decode(OpenTriviaResponse.self, from: data)
    guard decoded.response_code == 0 else { throw FetchError.apiCode(decoded.response_code) }
    let questions = decoded.results.compactMap { $0.makeQuestion() }
    guard !questions.isEmpty else { throw FetchError.emptyResults }
    return Array(questions.shuffled().prefix(amount))
  }
}

// MARK: - DTO

private struct OpenTriviaResponse: Decodable {
/// Przechowuje wartosc `response_code`.
  let response_code: Int
/// Przechowuje wartosc `results`.
  let results: [OpenTriviaItem]
}

private struct OpenTriviaItem: Decodable {
/// Przechowuje wartosc `question`.
  let question: String
/// Przechowuje wartosc `correct_answer`.
  let correct_answer: String
/// Przechowuje wartosc `incorrect_answers`.
  let incorrect_answers: [String]

/// Wykonuje operacje `makeQuestion`.
  func makeQuestion() -> Question? {
    let prompt = TriviaText.decode(question)
    let correct = TriviaText.decode(correct_answer)
    var answers = incorrect_answers.map { TriviaText.decode($0) } + [correct]
    answers.shuffle()
    guard let index = answers.firstIndex(of: correct), answers.count == 4 else { return nil }
    return Question(question: prompt, answers: answers, correctIndex: index)
  }
}

/// Reprezentuje typ `TriviaText`.
enum TriviaText {
/// Wykonuje operacje `decode`.
  static func decode(_ raw: String) -> String {
    let wrapped = "<!DOCTYPE html><html><body>\(raw)</body></html>"
    guard let data = wrapped.data(using: .utf8) else { return raw }
    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
      .documentType: NSAttributedString.DocumentType.html,
      .characterEncoding: String.Encoding.utf8.rawValue,
    ]
    guard let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
      return raw
    }
    return attributed.string
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\n", with: " ")
  }
}
