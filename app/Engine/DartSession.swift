import Combine
import Foundation

/// Zapisany stan rozgrywki 501 (przywracany po wyjściu z gry).
struct DartMatchState: Equatable, Codable {
/// Przechowuje wartosc `playerCount`.
  var playerCount: Int
/// Przechowuje wartosc `playerScores`.
  var playerScores: [Int]
/// Przechowuje wartosc `activePlayerIndex`.
  var activePlayerIndex: Int
/// Przechowuje wartosc `dartsLeftInTurn`.
  var dartsLeftInTurn: Int
/// Przechowuje wartosc `turnStartScore`.
  var turnStartScore: Int
/// Przechowuje wartosc `gameOver`.
  var gameOver: Bool
/// Przechowuje wartosc `winnerName`.
  var winnerName: String?
/// Przechowuje wartosc `lastHitLabel`.
  var lastHitLabel: String

  private enum CodingKeys: String, CodingKey {
    case playerCount, playerScores, activePlayerIndex, dartsLeftInTurn
    case turnStartScore, gameOver, winnerName, lastHitLabel
    case mode, player1Score, player2Score
  }

/// Inicjalizuje nowa instancje.
  init(
    playerCount: Int,
    playerScores: [Int],
    activePlayerIndex: Int,
    dartsLeftInTurn: Int,
    turnStartScore: Int,
    gameOver: Bool,
    winnerName: String?,
    lastHitLabel: String
  ) {
    self.playerCount = DartPlayers.clampCount(playerCount)
    self.playerScores = playerScores
    self.activePlayerIndex = activePlayerIndex
    self.dartsLeftInTurn = dartsLeftInTurn
    self.turnStartScore = turnStartScore
    self.gameOver = gameOver
    self.winnerName = winnerName
    self.lastHitLabel = lastHitLabel
  }

/// Inicjalizuje nowa instancje.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if c.contains(.playerScores) {
      playerCount = try c.decode(Int.self, forKey: .playerCount)
      playerScores = try c.decode([Int].self, forKey: .playerScores)
    } else {
      let mode = try c.decode(DartPlayMode.self, forKey: .mode)
      let p1 = try c.decode(Int.self, forKey: .player1Score)
      let p2 = try c.decode(Int.self, forKey: .player2Score)
      playerCount = mode == .solo ? 1 : 2
      playerScores = mode == .solo ? [p1] : [p1, p2]
    }
    activePlayerIndex = try c.decode(Int.self, forKey: .activePlayerIndex)
    dartsLeftInTurn = try c.decode(Int.self, forKey: .dartsLeftInTurn)
    turnStartScore = try c.decode(Int.self, forKey: .turnStartScore)
    gameOver = try c.decode(Bool.self, forKey: .gameOver)
    winnerName = try c.decodeIfPresent(String.self, forKey: .winnerName)
    lastHitLabel = try c.decode(String.self, forKey: .lastHitLabel)
    playerCount = DartPlayers.clampCount(playerCount)
  }

/// Wykonuje operacje `encode`.
  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(playerCount, forKey: .playerCount)
    try c.encode(playerScores, forKey: .playerScores)
    try c.encode(activePlayerIndex, forKey: .activePlayerIndex)
    try c.encode(dartsLeftInTurn, forKey: .dartsLeftInTurn)
    try c.encode(turnStartScore, forKey: .turnStartScore)
    try c.encode(gameOver, forKey: .gameOver)
    try c.encodeIfPresent(winnerName, forKey: .winnerName)
    try c.encode(lastHitLabel, forKey: .lastHitLabel)
  }

/// Przechowuje wartosc `canResume`.
  var canResume: Bool {
    !gameOver && hasProgress
  }

  private var hasProgress: Bool {
    playerScores.contains { $0 < DartPlayers.startingScore }
  }

/// Przechowuje wartosc `resumeSummary`.
  var resumeSummary: String {
    playerScores.map(String.init).joined(separator: " · ")
  }

/// Przechowuje wartosc `shouldPersist`.
  var shouldPersist: Bool {
    hasProgress || gameOver
  }
}

/// Ustawienia rozgrywki Dart (lobby / kalibracja → gra).
final class DartSession: ObservableObject {
  private enum Storage {
/// Przechowuje wartosc `savedMatchKey`.
    static let savedMatchKey = "dart.session.savedMatch"
  }

  @Published var playerCount: Int = 1 {
    didSet { normalizeRoster() }
  }

  @Published var playerNames: [String] = ["Gracz 1"] {
    didSet { normalizeRoster() }
  }

  @Published private(set) var savedMatch: DartMatchState?

  private var isNormalizingRoster = false

  /// Kompatybilność wsteczna (quiz itd. nie używają).
  var mode: DartPlayMode {
    playerCount > 1 ? .duo : .solo
  }

/// Przechowuje wartosc `player1Name`.
  var player1Name: String {
    get { name(at: 0) }
    set { setName(newValue, at: 0) }
  }

/// Przechowuje wartosc `player2Name`.
  var player2Name: String {
    get { name(at: 1) }
    set { setName(newValue, at: 1) }
  }

/// Inicjalizuje nowa instancje.
  init() {
    normalizeRoster()
    loadLobbyPreferences()
    loadSavedMatch()
  }

/// Przechowuje wartosc `isMultiplayer`.
  var isMultiplayer: Bool { playerCount > 1 }

/// Przechowuje wartosc `canResumeMatch`.
  var canResumeMatch: Bool {
    guard let savedMatch, savedMatch.playerCount == playerCount else { return false }
    return savedMatch.canResume
  }

/// Wykonuje operacje `name`.
  func name(at index: Int) -> String {
    guard playerNames.indices.contains(index) else {
      return DartPlayers.defaultName(index: index)
    }
    let trimmed = playerNames[index].trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? DartPlayers.defaultName(index: index) : trimmed
  }

/// Wykonuje operacje `setName`.
  func setName(_ value: String, at index: Int) {
    guard index >= 0, index < playerCount else { return }
    if playerNames.count <= index {
      normalizeRoster()
    }
    playerNames[index] = value
  }

/// Wykonuje operacje `persistMatch`.
  func persistMatch(_ state: DartMatchState) {
    guard state.shouldPersist else { return }
    savedMatch = state
    if let data = try? JSONEncoder().encode(state) {
      UserDefaults.standard.set(data, forKey: Storage.savedMatchKey)
    }
  }

/// Wykonuje operacje `clearSavedMatch`.
  func clearSavedMatch() {
    savedMatch = nil
    UserDefaults.standard.removeObject(forKey: Storage.savedMatchKey)
  }

/// Wykonuje operacje `cyclePlayerCount`.
  func cyclePlayerCount() {
    let next = playerCount >= DartPlayers.maxCount ? DartPlayers.minCount : playerCount + 1
    if savedMatch?.playerCount != next {
      clearSavedMatch()
    }
    playerCount = next
    persistLobbyPreferences()
  }

  /// Kompatybilność z menu TV / telefonem.
  func toggleMode() {
    cyclePlayerCount()
  }

/// Wykonuje operacje `persistLobbyPreferences`.
  func persistLobbyPreferences() {
    DartLobbySettings.savePlayerCount(playerCount)
    DartLobbySettings.savePlayerNames(playerNames)
  }

  private func normalizeRoster() {
    guard !isNormalizingRoster else { return }
    isNormalizingRoster = true
    defer { isNormalizingRoster = false }

    let count = DartPlayers.clampCount(playerCount)
    if playerCount != count { playerCount = count }
    let normalized = DartPlayers.normalizedNames(playerNames, count: count)
    if normalized != playerNames { playerNames = normalized }
  }

  private func loadLobbyPreferences() {
    if let saved = DartLobbySettings.loadPlayerCount() {
      playerCount = saved
    } else if let legacyMode = DartLobbySettings.loadMode() {
      playerCount = legacyMode == .solo ? 1 : 2
    }
    if let names = DartLobbySettings.loadPlayerNames(), !names.isEmpty {
      playerNames = names
    } else {
      let legacy = DartLobbySettings.loadPlayerNamesLegacy()
      playerNames = DartPlayers.normalizedNames(
        [legacy.0 ?? "Gracz 1", legacy.1 ?? "Gracz 2"],
        count: playerCount
      )
    }
    normalizeRoster()
  }

  private func loadSavedMatch() {
    guard
      let data = UserDefaults.standard.data(forKey: Storage.savedMatchKey),
      let state = try? JSONDecoder().decode(DartMatchState.self, from: data)
    else { return }
    savedMatch = state
    playerCount = state.playerCount
    normalizeRoster()
  }
}

/// Legacy — tylko migracja zapisów i quiz.
enum DartPlayMode: String, CaseIterable, Identifiable, Equatable, Codable {
  case solo
  case duo

/// Przechowuje wartosc `id`.
  var id: String { rawValue }

/// Przechowuje wartosc `title`.
  var title: String {
    switch self {
    case .solo: return "1 gracz"
    case .duo: return "2 graczy"
    }
  }

/// Przechowuje wartosc `subtitle`.
  var subtitle: String {
    switch self {
    case .solo: return "501 · 3 lotki na turę"
    case .duo: return "501 · na zmianę · 3 lotki"
    }
  }
}
