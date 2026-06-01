import Foundation
import SwiftUI

/// Pozycje menu lobby (telefon — pełna lista).
enum DartLobbyMenuItem: Int, CaseIterable {
  case play = 0
  case calibrate = 1
  case toggleMode = 2
  case toggleTVBoard = 3
  case invertX = 4
  case invertY = 5
  case toggleKeepAwake = 6
  case back = 7
  case newGame = 8

  static let slotCount = 9

  func title(canResume: Bool) -> String {
    switch self {
    case .play: return canResume ? "KONTYNUUJ GRĘ" : "ROZPOCZNIJ GRĘ"
    case .newGame: return "NOWA GRA"
    case .calibrate: return "KALIBRACJA TRIKI"
    case .toggleMode: return "TRYB GRACZY"
    case .toggleTVBoard: return "TARCZA NA TV"
    case .invertX: return "ODWRÓĆ LEWO / PRAWO"
    case .invertY: return "ODWRÓĆ GÓRA / DÓŁ"
    case .toggleKeepAwake: return "NIE WYŁĄCZAJ EKRANU"
    case .back: return "WSTECZ"
    }
  }
}

/// Jedna odpowiedź na TV (jak A–D w quizie).
struct TVMenuChoice: Equatable, Identifiable {
  var id: Int { slot }
  let slot: Int
  let letter: String
  let text: String
  let menuItem: DartLobbyMenuItem?
  let navigation: DartLobbyTVNavigation?
}

enum DartLobbyTVNavigation: Equatable {
  case openOptions
  case openMain
}

/// Menu TV: 4 opcje na ekran (jak pytania w quizie), 2 strony.
enum DartLobbyTVLayout {
  static let trikiSlotCount = 4
  static let pageCount = 2
  static let answerLetters = ["A", "B", "C", "D"]
  static let answerColors: [Color] = [
    NeonTheme.neonOrange,
    NeonTheme.neonCyan,
    NeonTheme.neonGreen,
    NeonTheme.neonMagenta,
  ]

  static func accent(for slot: Int) -> Color {
    guard slot >= 0, slot < answerColors.count else { return NeonTheme.neonCyan }
    return answerColors[slot]
  }

  static func choices(page: Int, payload: DartTVLobbyPayload) -> [TVMenuChoice] {
    switch page {
    case 0:
      if payload.canResume {
        return [
          TVMenuChoice(
            slot: 0,
            letter: "A",
            text: DartLobbyMenuItem.play.title(canResume: true),
            menuItem: .play,
            navigation: nil
          ),
          TVMenuChoice(
            slot: 1,
            letter: "B",
            text: DartLobbyMenuItem.newGame.title(canResume: false),
            menuItem: .newGame,
            navigation: nil
          ),
          TVMenuChoice(
            slot: 2,
            letter: "C",
            text: DartLobbyMenuItem.calibrate.title(canResume: false),
            menuItem: .calibrate,
            navigation: nil
          ),
          TVMenuChoice(
            slot: 3,
            letter: "D",
            text: "WIĘCEJ OPCJI →",
            menuItem: nil,
            navigation: .openOptions
          ),
        ]
      }
      return [
        TVMenuChoice(
          slot: 0,
          letter: "A",
          text: DartLobbyMenuItem.play.title(canResume: false),
          menuItem: .play,
          navigation: nil
        ),
        TVMenuChoice(
          slot: 1,
          letter: "B",
          text: DartLobbyMenuItem.calibrate.title(canResume: false),
          menuItem: .calibrate,
          navigation: nil
        ),
        TVMenuChoice(
          slot: 2,
          letter: "C",
          text: "\(DartLobbyMenuItem.toggleMode.title(canResume: false)): \(payload.playerCount)",
          menuItem: .toggleMode,
          navigation: nil
        ),
        TVMenuChoice(
          slot: 3,
          letter: "D",
          text: "WIĘCEJ OPCJI →",
          menuItem: nil,
          navigation: .openOptions
        ),
      ]
    default:
      return [
        TVMenuChoice(
          slot: 0,
          letter: "A",
          text: "\(DartLobbyMenuItem.toggleTVBoard.title(canResume: false)): \(payload.dartBoardOnTV ? "TAK" : "NIE")",
          menuItem: .toggleTVBoard,
          navigation: nil
        ),
        TVMenuChoice(
          slot: 1,
          letter: "B",
          text: "\(DartLobbyMenuItem.invertX.title(canResume: false))\(payload.invertX ? " ✓" : "")",
          menuItem: .invertX,
          navigation: nil
        ),
        TVMenuChoice(
          slot: 2,
          letter: "C",
          text: "\(DartLobbyMenuItem.invertY.title(canResume: false))\(payload.invertY ? " ✓" : "")",
          menuItem: .invertY,
          navigation: nil
        ),
        TVMenuChoice(
          slot: 3,
          letter: "D",
          text: "◀ MENU GŁÓWNE",
          menuItem: nil,
          navigation: .openMain
        ),
      ]
    }
  }

  static func pageTitle(page: Int) -> String {
    page == 0 ? "CO CHCESZ ZROBIĆ?" : "USTAWIENIA GRY"
  }

  static func pageSubtitle(page: Int) -> String {
    page == 0
      ? "Strona 1/2 · wybierz jak w quizie (A–D)"
      : "Strona 2/2 · D = powrót do menu głównego"
  }

  static func choicesWithBack(page: Int, payload: DartTVLobbyPayload) -> [TVMenuChoice] {
    choices(page: page, payload: payload)
  }
}

struct DartTVLobbyPayload: Equatable {
  var isActive = false
  var menuPage = 0
  var focusIndex: Int?
  var holdProgress: Double = 0
  var playerCount = 1
  var playerNames: [String] = ["Gracz 1"]
  var player1Name = "Gracz 1"
  var player2Name = "Gracz 2"
  var mode: DartPlayMode = .solo
  var dartBoardOnTV = false
  var keepScreenOn = true
  var canResume = false
  var resumeSummary: String?
  var profileP1Ready = false
  var profileP2Ready = false
  var invertX = false
  var invertY = false
  var hasTriki = false
}
