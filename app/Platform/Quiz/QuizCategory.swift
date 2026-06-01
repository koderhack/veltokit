import Foundation

struct QuizCategory: Identifiable, Equatable, Codable, Sendable {
  let id: Int
  let namePL: String

  static let any = QuizCategory(id: 0, namePL: "Losowa mieszanka")
}

enum QuizCategoryService {
  private static let url = URL(string: "https://opentdb.com/api_category.php")!

  static func fetchCategories() async throws -> [QuizCategory] {
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw OpenTriviaClient.FetchError.badStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
    }
    let decoded = try JSONDecoder().decode(CategoryResponse.self, from: data)
    let mapped = decoded.trivia_categories.map {
      QuizCategory(id: $0.id, namePL: polishName(for: $0.name))
    }
    return [QuizCategory.any] + mapped.sorted { $0.namePL < $1.namePL }
  }

  private static func polishName(for english: String) -> String {
    let map: [String: String] = [
      "General Knowledge": "Wiedza ogólna",
      "Entertainment: Books": "Książki",
      "Entertainment: Film": "Film",
      "Entertainment: Music": "Muzyka",
      "Entertainment: Musicals & Theatres": "Teatr",
      "Entertainment: Television": "Telewizja",
      "Entertainment: Video Games": "Gry wideo",
      "Entertainment: Board Games": "Gry planszowe",
      "Science & Nature": "Nauka i przyroda",
      "Science: Computers": "Komputery",
      "Science: Mathematics": "Matematyka",
      "Mythology": "Mitologia",
      "Sports": "Sport",
      "Geography": "Geografia",
      "History": "Historia",
      "Politics": "Polityka",
      "Art": "Sztuka",
      "Celebrities": "Gwiazdy",
      "Animals": "Zwierzęta",
      "Vehicles": "Pojazdy",
      "Entertainment: Comics": "Komiksy",
      "Science: Gadgets": "Gadżety",
      "Entertainment: Japanese Anime & Manga": "Anime i manga",
      "Entertainment: Cartoon & Animations": "Kreskówki",
    ]
    return map[english] ?? english
  }
}

private struct CategoryResponse: Decodable {
  let trivia_categories: [CategoryItem]
}

private struct CategoryItem: Decodable {
  let id: Int
  let name: String
}
