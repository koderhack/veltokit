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

/// Przechowuje wartosc `slotCount`.
  static let slotCount = 9

/// Wykonuje operacje `title`.
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
/// Przechowuje wartosc `id`.
  var id: Int { slot }
/// Przechowuje wartosc `slot`.
  let slot: Int
/// Przechowuje wartosc `letter`.
  let letter: String
/// Przechowuje wartosc `text`.
  let text: String
/// Przechowuje wartosc `menuItem`.
  let menuItem: DartLobbyMenuItem?
/// Przechowuje wartosc `navigation`.
  let navigation: DartLobbyTVNavigation?
}

/// Reprezentuje typ `DartLobbyTVNavigation`.
enum DartLobbyTVNavigation: Equatable {
  case openOptions
  case openMain
}

/// Menu TV: 4 opcje na ekran (jak pytania w quizie), 2 strony.
enum DartLobbyTVLayout {
/// Przechowuje wartosc `trikiSlotCount`.
  static let trikiSlotCount = 4
/// Przechowuje wartosc `pageCount`.
  static let pageCount = 2
/// Przechowuje wartosc `answerLetters`.
  static let answerLetters = ["A", "B", "C", "D"]
/// Przechowuje wartosc `answerColors`.
  static let answerColors: [Color] = [
    NeonTheme.neonOrange,
    NeonTheme.neonCyan,
    NeonTheme.neonGreen,
    NeonTheme.neonMagenta,
  ]

/// Wykonuje operacje `accent`.
  static func accent(for slot: Int) -> Color {
    guard slot >= 0, slot < answerColors.count else { return NeonTheme.neonCyan }
    return answerColors[slot]
  }

/// Wykonuje operacje `choices`.
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

/// Wykonuje operacje `pageTitle`.
  static func pageTitle(page: Int) -> String {
    page == 0 ? "CO CHCESZ ZROBIĆ?" : "USTAWIENIA GRY"
  }

/// Wykonuje operacje `pageSubtitle`.
  static func pageSubtitle(page: Int) -> String {
    page == 0
      ? "Strona 1/2 · wybierz jak w quizie (A–D)"
      : "Strona 2/2 · D = powrót do menu głównego"
  }

/// Wykonuje operacje `choicesWithBack`.
  static func choicesWithBack(page: Int, payload: DartTVLobbyPayload) -> [TVMenuChoice] {
    choices(page: page, payload: payload)
  }
}

/// Reprezentuje typ `DartTVLobbyPayload`.
struct DartTVLobbyPayload: Equatable {
/// Przechowuje wartosc `isActive`.
  var isActive = false
/// Przechowuje wartosc `menuPage`.
  var menuPage = 0
/// Przechowuje wartosc `focusIndex`.
  var focusIndex: Int?
/// Przechowuje wartosc `holdProgress`.
  var holdProgress: Double = 0
/// Przechowuje wartosc `playerCount`.
  var playerCount = 1
/// Przechowuje wartosc `playerNames`.
  var playerNames: [String] = ["Gracz 1"]
/// Przechowuje wartosc `player1Name`.
  var player1Name = "Gracz 1"
/// Przechowuje wartosc `player2Name`.
  var player2Name = "Gracz 2"
/// Przechowuje wartosc `mode`.
  var mode: DartPlayMode = .solo
/// Przechowuje wartosc `dartBoardOnTV`.
  var dartBoardOnTV = false
/// Przechowuje wartosc `keepScreenOn`.
  var keepScreenOn = true
/// Przechowuje wartosc `canResume`.
  var canResume = false
/// Przechowuje wartosc `resumeSummary`.
  var resumeSummary: String?
/// Przechowuje wartosc `profileP1Ready`.
  var profileP1Ready = false
/// Przechowuje wartosc `profileP2Ready`.
  var profileP2Ready = false
/// Przechowuje wartosc `invertX`.
  var invertX = false
/// Przechowuje wartosc `invertY`.
  var invertY = false
/// Przechowuje wartosc `hasTriki`.
  var hasTriki = false
}
