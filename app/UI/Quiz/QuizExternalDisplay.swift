import Combine
import SwiftUI
import UIKit

enum ArcadeTVSettings {
  static let dartBoardOnTVKey = "dartBoardOnTV"
  static let bowlingOnTVKey = "bowlingOnTV"
  static let bowlingInvertLateralKey = "bowlingInvertLateral"

  static func registerDefaults() {
    UserDefaults.standard.register(defaults: [
      dartBoardOnTVKey: false,
      bowlingOnTVKey: false,
    ])
  }

  /// Tryb „tarcza/tor na TV” — tylko gdy użytkownik go włączył i jest drugi ekran.
  static func dartUsesExternalBoard(dartBoardOnTV: Bool, externalConnected: Bool) -> Bool {
    dartBoardOnTV && externalConnected
  }

  static func bowlingUsesExternalLane(bowlingOnTV: Bool, externalConnected: Bool) -> Bool {
    bowlingOnTV && externalConnected
  }
}

struct DartCalibrationTVPayload: Equatable {
  var isActive = false
  var step: DartCalibrationStep = .neutral
  var progress: Double = 0
  var playerName = ""
  var playerIndex = 0
  var playerCount = 1
  var focusIndex: Int?
  var holdProgress: Double = 0
  var showPlayMenu = false
  var menuChoices: [TVMenuChoice] = []
}

struct DartTVPayload: Equatable {
  var isDartActive = false
  var drawCommands: [DrawCommand] = []
  var score = 0
  var playerCount = 1
  var playerScores: [Int] = [501]
  var playerNames: [String] = ["Gracz 1"]
  var player1Score = 0
  var player2Score = 0
  var player1Name = "Gracz 1"
  var player2Name = "Gracz 2"
  var activePlayerIndex = 0
  var activePlayerName = ""
  var mode: DartPlayMode = .solo
  var dartsLeftInTurn = 3
  var gameOver = false
  var winnerName: String?
  var lastHitLabel = ""
  var feedbackLabel: String?
  var turnAnnouncement: String?
  var aimGridX = DartBoardLayout.centerX
  var aimGridY = DartBoardLayout.centerY
  var throwPrimed = false
  var flightActive = false
  var flightGridX = DartBoardLayout.centerX
  var flightGridY = DartBoardLayout.centerY
  var flightProgress = 0.0
  var boardMarkers: [DartBoardMarker] = []
  var startCountdown: Int?
  var awaitingTurnStart = false
}

struct QuizTVPayload: Equatable {
  var isQuizActive = false
  var questionText = ""
  var answers: [String] = []
  var questionIndex = 0
  var questionTotal = 0
  var roundLabel = ""
  var activePlayerName = ""
  var player1Score = 0
  var player2Score = 0
  var mode: QuizPlayMode = .solo
  var feedbackLabel: String?
  var selectedIndex: Int?
  var holdAnswerIndex: Int?
  var holdProgress: Double = 0
  var isFinished = false
}

struct BowlingTVLobbyPayload: Equatable {
  var isActive = false
  var modeTitle = ""
  var playerNames: [String] = []
}

struct BowlingTVPayload: Equatable {
  var isBowlingActive = false
  var hud: BowlingGame.HUD?
}

/// Drugi ekran (AirPlay / HDMI): pytanie na TV, sterowanie na telefonie.
@MainActor
final class QuizExternalDisplay: ObservableObject {
  @Published private(set) var payload = QuizTVPayload()
  @Published private(set) var dartPayload = DartTVPayload()
  @Published private(set) var dartCalibrationPayload = DartCalibrationTVPayload()
  @Published private(set) var dartLobbyPayload = DartTVLobbyPayload()
  @Published private(set) var bowlingLobbyPayload = BowlingTVLobbyPayload()
  @Published private(set) var bowlingPayload = BowlingTVPayload()
  /// Scena 3D współdzielona z telefonem (renderowana na TV).
  @Published var bowlingScene: BowlingGameScene?
  @Published private(set) var isExternalScreenConnected = false

  private var externalWindow: UIWindow?
  private var screenObservers: [NSObjectProtocol] = []

  init() {
    let center = NotificationCenter.default
    screenObservers.append(
      center.addObserver(forName: UIScreen.didConnectNotification, object: nil, queue: .main) { [weak self] note in
        guard let screen = note.object as? UIScreen else { return }
        Task { @MainActor in self?.attach(screen: screen) }
      }
    )
    screenObservers.append(
      center.addObserver(forName: UIScreen.didDisconnectNotification, object: nil, queue: .main) { [weak self] note in
        guard let screen = note.object as? UIScreen else { return }
        Task { @MainActor in self?.detach(screen: screen) }
      }
    )
    for screen in UIScreen.screens where screen != UIScreen.main {
      attach(screen: screen)
    }
  }

  deinit {
    screenObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  func setQuizActive(_ active: Bool) {
    payload.isQuizActive = active
    if !active {
      payload = QuizTVPayload()
    }
    if active {
      dartPayload = DartTVPayload()
      dartLobbyPayload = DartTVLobbyPayload()
      clearBowlingDisplay()
    }
  }

  private func clearBowlingDisplay() {
    bowlingPayload = BowlingTVPayload()
    bowlingLobbyPayload = BowlingTVLobbyPayload()
    bowlingScene = nil
  }

  func setBowlingLobbyActive(_ active: Bool) {
    bowlingLobbyPayload.isActive = active
    if !active {
      bowlingLobbyPayload = BowlingTVLobbyPayload()
    }
    if active {
      payload = QuizTVPayload()
      dartPayload = DartTVPayload()
      dartLobbyPayload = DartTVLobbyPayload()
      dartCalibrationPayload = DartCalibrationTVPayload()
      bowlingPayload = BowlingTVPayload()
      bowlingScene = nil
    }
  }

  func updateBowlingLobby(modeTitle: String, playerNames: [String]) {
    guard bowlingLobbyPayload.isActive else { return }
    bowlingLobbyPayload.modeTitle = modeTitle
    bowlingLobbyPayload.playerNames = playerNames
  }

  func setBowlingActive(_ active: Bool) {
    bowlingPayload.isBowlingActive = active
    if !active {
      bowlingPayload = BowlingTVPayload()
      bowlingScene = nil
    }
    if active {
      payload = QuizTVPayload()
      dartPayload = DartTVPayload()
      dartLobbyPayload = DartTVLobbyPayload()
      dartCalibrationPayload = DartCalibrationTVPayload()
      bowlingLobbyPayload = BowlingTVLobbyPayload()
    }
  }

  func updateBowling(hud: BowlingGame.HUD?, scene: BowlingGameScene?) {
    guard bowlingPayload.isBowlingActive else { return }
    bowlingPayload = BowlingTVPayload(isBowlingActive: true, hud: hud)
    if bowlingScene !== scene {
      bowlingScene = scene
    }
  }

  func setDartActive(_ active: Bool) {
    dartPayload.isDartActive = active
    if !active {
      dartPayload = DartTVPayload()
    }
    if active {
      payload = QuizTVPayload()
      setDartCalibrationActive(false)
      setDartLobbyActive(false)
      clearBowlingDisplay()
    }
  }

  func setDartLobbyActive(_ active: Bool) {
    dartLobbyPayload.isActive = active
    if !active {
      dartLobbyPayload = DartTVLobbyPayload()
    }
    if active {
      dartPayload = DartTVPayload()
      dartCalibrationPayload = DartCalibrationTVPayload()
      payload = QuizTVPayload()
      clearBowlingDisplay()
    }
  }

  func updateDartLobby(_ state: DartTVLobbyPayload) {
    guard dartLobbyPayload.isActive else { return }
    dartLobbyPayload = state
  }

  func setDartCalibrationActive(_ active: Bool) {
    dartCalibrationPayload.isActive = active
    if !active {
      dartCalibrationPayload = DartCalibrationTVPayload()
    }
    if active {
      dartPayload = DartTVPayload()
      dartLobbyPayload = DartTVLobbyPayload()
      payload = QuizTVPayload()
      clearBowlingDisplay()
    }
  }

  func updateDartCalibration(
    step: DartCalibrationStep,
    progress: Double,
    playerName: String,
    playerIndex: Int,
    playerCount: Int,
    focusIndex: Int? = nil,
    holdProgress: Double = 0,
    showPlayMenu: Bool = false,
    menuChoices: [TVMenuChoice] = []
  ) {
    guard dartCalibrationPayload.isActive else { return }
    dartCalibrationPayload.step = step
    dartCalibrationPayload.progress = progress
    dartCalibrationPayload.playerName = playerName
    dartCalibrationPayload.playerIndex = playerIndex
    dartCalibrationPayload.playerCount = playerCount
    dartCalibrationPayload.focusIndex = focusIndex
    dartCalibrationPayload.holdProgress = holdProgress
    dartCalibrationPayload.showPlayMenu = showPlayMenu
    dartCalibrationPayload.menuChoices = menuChoices
  }

  func updateDart(commands: [DrawCommand], hud: DartGame.HUD?) {
    guard dartPayload.isDartActive else { return }
    dartPayload.drawCommands = commands
    dartPayload.score = hud?.score ?? 0
    dartPayload.playerCount = hud?.playerCount ?? 1
    dartPayload.playerScores = hud?.playerScores ?? [501]
    dartPayload.playerNames = hud?.playerNames ?? ["Gracz 1"]
    dartPayload.player1Score = hud?.player1Score ?? 0
    dartPayload.player2Score = hud?.player2Score ?? 0
    dartPayload.player1Name = hud?.player1Name ?? "Gracz 1"
    dartPayload.player2Name = hud?.player2Name ?? "Gracz 2"
    dartPayload.activePlayerIndex = hud?.activePlayerIndex ?? 0
    dartPayload.activePlayerName = hud?.activePlayerName ?? ""
    dartPayload.mode = hud?.mode ?? .solo
    dartPayload.dartsLeftInTurn = hud?.dartsLeftInTurn ?? 3
    dartPayload.gameOver = hud?.gameOver ?? false
    dartPayload.winnerName = hud?.winnerName
    dartPayload.lastHitLabel = hud?.lastHitLabel ?? ""
    dartPayload.feedbackLabel = hud?.feedbackLabel
    dartPayload.turnAnnouncement = hud?.turnAnnouncement
    dartPayload.aimGridX = hud?.aimGridX ?? DartBoardLayout.centerX
    dartPayload.aimGridY = hud?.aimGridY ?? DartBoardLayout.centerY
    dartPayload.throwPrimed = hud?.throwPrimed ?? false
    dartPayload.flightActive = hud?.flightActive ?? false
    dartPayload.flightGridX = hud?.flightGridX ?? DartBoardLayout.centerX
    dartPayload.flightGridY = hud?.flightGridY ?? DartBoardLayout.centerY
    dartPayload.flightProgress = hud?.flightProgress ?? 0
    dartPayload.boardMarkers = hud?.boardMarkers ?? []
    dartPayload.startCountdown = hud?.startCountdown
    dartPayload.awaitingTurnStart = hud?.awaitingTurnStart ?? false
  }

  func update(hud: QuizGame.HUD?, session: QuizSession) {
    guard payload.isQuizActive, let hud else { return }
    payload = QuizTVPayload(
      isQuizActive: true,
      questionText: hud.questionText,
      answers: hud.answers,
      questionIndex: hud.questionIndex,
      questionTotal: hud.questionTotal,
      roundLabel: hud.roundLabel,
      activePlayerName: hud.activePlayerName,
      player1Score: hud.player1Score,
      player2Score: hud.player2Score,
      mode: hud.mode,
      feedbackLabel: hud.feedbackLabel,
      selectedIndex: hud.selected,
      holdAnswerIndex: hud.holdAnswerIndex,
      holdProgress: hud.holdProgress,
      isFinished: hud.isFinished
    )
  }

  private func attach(screen: UIScreen) {
    guard screen != UIScreen.main else { return }
    Task { @MainActor in
      for _ in 0 ..< 8 {
        if let scene = windowScene(for: screen) {
          installWindow(on: scene)
          return
        }
        try? await Task.sleep(nanoseconds: 150_000_000)
      }
    }
  }

  private func installWindow(on scene: UIWindowScene) {
    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIHostingController(
      rootView: ArcadeTVRootView().environmentObject(self)
    )
    window.rootViewController?.view.backgroundColor = .black
    window.isHidden = false
    externalWindow = window
    if !isExternalScreenConnected {
      QuizSFX.tvConnected()
    }
    isExternalScreenConnected = true
  }

  private func detach(screen: UIScreen) {
    guard externalWindow?.windowScene?.screen == screen else { return }
    externalWindow?.isHidden = true
    externalWindow = nil
    let stillConnected = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .contains { $0.screen != UIScreen.main }
    if isExternalScreenConnected, !stillConnected {
      QuizSFX.tvDisconnected()
    }
    isExternalScreenConnected = stillConnected
  }

  private func windowScene(for screen: UIScreen) -> UIWindowScene? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.screen == screen }
  }
}

// MARK: - Korzeń TV (quiz / dart)

struct ArcadeTVRootView: View {
  @EnvironmentObject private var display: QuizExternalDisplay

  var body: some View {
    if display.dartLobbyPayload.isActive {
      DartTVLobbyView()
    } else if display.dartCalibrationPayload.isActive {
      DartCalibrationTVView()
    } else if display.bowlingLobbyPayload.isActive {
      BowlingTVLobbyView()
    } else if display.dartPayload.isDartActive {
      DartTVView()
    } else if display.bowlingPayload.isBowlingActive {
      BowlingTVView()
    } else {
      QuizTVView()
    }
  }
}

// MARK: - Wiersz odpowiedzi TV (quiz + dart)

struct TVQuizAnswerRow: View {
  let letter: String
  let text: String
  let accent: Color
  let isSelected: Bool
  let isHolding: Bool
  let holdProgress: Double
  let type: TVTypography

  var body: some View {
    HStack(spacing: type.contentPadding * 0.65) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [accent, accent.opacity(0.65)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: type.answerBadge, height: type.answerBadge)
          .overlay(
            Circle()
              .stroke(Color.white.opacity(isSelected ? 0.9 : 0.35), lineWidth: isSelected ? 4 : 2)
          )
        if isHolding {
          Circle()
            .trim(from: 0, to: holdProgress)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .frame(width: type.answerBadge * 1.15, height: type.answerBadge * 1.15)
            .rotationEffect(.degrees(-90))
        }
        Text(letter)
          .font(.system(size: type.answerLetter, weight: .black, design: .rounded))
          .foregroundStyle(.white)
      }

      Text(text)
        .font(.system(size: type.answer, weight: isSelected ? .bold : .semibold, design: .rounded))
        .foregroundStyle(.white)
        .lineSpacing(type.scale * 4)
        .minimumScaleFactor(0.88)
        .frame(maxWidth: .infinity, alignment: .leading)

      if isSelected || isHolding {
        Image(systemName: isHolding ? "hand.tap.fill" : "checkmark.circle.fill")
          .font(.system(size: type.answer * 0.9, weight: .bold))
          .foregroundStyle(isHolding ? NeonTheme.neonMagenta : accent)
      }
    }
    .padding(.horizontal, type.contentPadding * 0.75)
    .padding(.vertical, type.contentPadding * 0.55)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(isSelected || isHolding ? accent.opacity(0.18) : Color.white.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(
          isHolding ? NeonTheme.neonMagenta : (isSelected ? accent.opacity(0.85) : Color.white.opacity(0.14)),
          lineWidth: isHolding ? 5 : (isSelected ? 4 : 2)
        )
    )
    .scaleEffect(isSelected ? 1.02 : 1)
    .animation(.easeOut(duration: 0.2), value: isSelected)
  }
}

struct TVQuizBackdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.02, green: 0.04, blue: 0.18),
          Color(red: 0.04, green: 0.02, blue: 0.12),
          Color.black,
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [NeonTheme.neonCyan.opacity(0.14), .clear],
        center: .top,
        startRadius: 40,
        endRadius: 520
      )
      RadialGradient(
        colors: [NeonTheme.neonMagenta.opacity(0.08), .clear],
        center: .bottomTrailing,
        startRadius: 20,
        endRadius: 400
      )
    }
    .ignoresSafeArea()
  }
}

struct TVQuizShowFrame<Content: View>: View {
  let type: TVTypography
  @ViewBuilder let content: () -> Content

  var body: some View {
    content()
      .padding(.horizontal, type.contentPadding)
      .padding(.vertical, type.contentPadding * 0.85)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(
            LinearGradient(
              colors: [
                NeonTheme.neonYellow.opacity(0.85),
                NeonTheme.neonOrange.opacity(0.5),
                NeonTheme.neonCyan.opacity(0.4),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: max(4, type.scale * 2)
          )
      )
      .padding(type.contentPadding * 0.6)
  }
}

// MARK: - Widok TV — lobby Dart (menu jak quiz)

struct DartTVLobbyView: View {
  @EnvironmentObject private var display: QuizExternalDisplay

  var body: some View {
    let payload = display.dartLobbyPayload
    GeometryReader { geo in
      let type = TVTypography(size: geo.size)
      let choices = DartLobbyTVLayout.choicesWithBack(page: payload.menuPage, payload: payload)
      ZStack {
        TVQuizBackdrop()
        TVQuizShowFrame(type: type) {
          VStack(spacing: 0) {
            dartLobbyHeader(payload: payload, type: type)
              .padding(.bottom, type.contentPadding * 0.65)

            dartMenuPromptBlock(payload: payload, type: type)
              .padding(.bottom, type.contentPadding * 0.75)

            if payload.canResume, let summary = payload.resumeSummary {
              Text("WZNÓW · \(summary)")
                .font(.system(size: type.headerMeta, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.neonGreen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, type.contentPadding * 0.5)
            }

            VStack(spacing: type.answerSpacing) {
              ForEach(choices) { choice in
                TVQuizAnswerRow(
                  letter: choice.letter,
                  text: choice.text,
                  accent: DartLobbyTVLayout.accent(for: choice.slot),
                  isSelected: payload.focusIndex == choice.slot,
                  isHolding: payload.focusIndex == choice.slot,
                  holdProgress: payload.focusIndex == choice.slot ? payload.holdProgress : 0,
                  type: type
                )
              }
            }

            Spacer(minLength: 8)

            Text(
              payload.hasTriki
                ? "OBRÓT = WYBÓR · HOLD LUB PRZYCISK = OK"
                : "PODŁĄCZ TRIKI · OPCJE NA TELEFONIE"
            )
            .font(.system(size: type.footer, weight: .heavy, design: .monospaced))
            .foregroundStyle(payload.hasTriki ? NeonTheme.neonYellow.opacity(0.75) : NeonTheme.neonOrange)
            .tracking(2)
            .frame(maxWidth: .infinity)
            .padding(.top, type.contentPadding * 0.5)
          }
        }
      }
    }
    .preferredColorScheme(.dark)
    .ignoresSafeArea()
  }

  private func dartLobbyHeader(payload: DartTVLobbyPayload, type: TVTypography) -> some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 8) {
        Text("DART · MENU")
          .font(.system(size: type.headerMeta, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonCyan)
        Text(
          payload.playerCount <= 1
            ? payload.playerNames.first?.uppercased() ?? "GRACZ 1"
            : payload.playerNames.map { $0.uppercased() }.joined(separator: " · ")
        )
        .font(.system(size: type.headerPlayer, weight: .black, design: .rounded))
        .foregroundStyle(NeonTheme.neonMagenta)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        Text("STRONA")
          .font(.system(size: type.headerQuestionLabel, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white.opacity(0.5))
        Text("\(payload.menuPage + 1) / \(DartLobbyTVLayout.pageCount)")
          .font(.system(size: type.headerQuestion, weight: .black, design: .rounded))
          .foregroundStyle(NeonTheme.neonYellow)
      }
      dartProfileBadge(payload: payload, type: type)
        .padding(.leading, type.contentPadding * 0.75)
    }
  }

  private func dartProfileBadge(payload: DartTVLobbyPayload, type: TVTypography) -> some View {
    let ready = payload.profileP1Ready && (payload.playerCount <= 1 || payload.profileP2Ready)
    return Text(ready ? "✓ TRIKI" : "!")
      .font(.system(size: type.score * 0.55, weight: .black, design: .rounded))
      .foregroundStyle(ready ? NeonTheme.neonGreen : NeonTheme.neonOrange)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.black.opacity(0.45))
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(NeonTheme.neonYellow.opacity(0.5), lineWidth: 2))
      )
  }

  private func dartMenuPromptBlock(payload: DartTVLobbyPayload, type: TVTypography) -> some View {
    let title = DartLobbyTVLayout.pageTitle(page: payload.menuPage)
    return VStack(spacing: type.contentPadding * 0.35) {
      Text(title)
        .font(.system(size: type.questionFont(for: title), weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.7)
      Text(DartLobbyTVLayout.pageSubtitle(page: payload.menuPage))
        .font(.system(size: type.footnote, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.55))
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, type.contentPadding * 0.65)
    .padding(.vertical, type.contentPadding * 0.45)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 2))
    )
  }
}

// MARK: - Widok TV — kalibracja Dart

struct DartCalibrationTVView: View {
  @EnvironmentObject private var display: QuizExternalDisplay

  var body: some View {
    let payload = display.dartCalibrationPayload
    GeometryReader { geo in
      let scale = max(1.2, min(2.2, geo.size.width / 900))
      ZStack {
        Color.black.ignoresSafeArea()
        RadialGradient(
          colors: [NeonTheme.neonCyan.opacity(0.15), .clear],
          center: .center,
          startRadius: 20,
          endRadius: geo.size.width * 0.55
        )
        .ignoresSafeArea()

        VStack(spacing: 28 * scale) {
          Text("KALIBRACJA DART")
            .font(.system(size: 34 * scale, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonCyan)

          if payload.playerCount > 1 {
            Text("\(payload.playerName.uppercased()) · GRACZ \(payload.playerIndex + 1)/\(payload.playerCount)")
              .font(.system(size: 18 * scale, weight: .bold, design: .monospaced))
              .foregroundStyle(NeonTheme.neonMagenta)
          } else {
            Text(payload.playerName.uppercased())
              .font(.system(size: 18 * scale, weight: .bold, design: .monospaced))
              .foregroundStyle(NeonTheme.neonMagenta)
          }

          stepIndicator(payload: payload, scale: scale)

          Text(payload.step.title)
            .font(.system(size: 42 * scale, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)

          Text(payload.step.tvDetail)
            .font(.system(size: 20 * scale, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 48 * scale)

          progressRing(progress: payload.progress, scale: scale)

          if !payload.menuChoices.isEmpty {
            let calType = TVTypography(size: geo.size)
            VStack(spacing: calType.answerSpacing) {
              ForEach(payload.menuChoices) { choice in
                TVQuizAnswerRow(
                  letter: choice.letter,
                  text: choice.text,
                  accent: DartLobbyTVLayout.accent(for: choice.slot),
                  isSelected: payload.focusIndex == choice.slot,
                  isHolding: payload.focusIndex == choice.slot,
                  holdProgress: payload.focusIndex == choice.slot ? payload.holdProgress : 0,
                  type: calType
                )
              }
            }
            .padding(.horizontal, 24 * scale)
          }

          VStack(spacing: 6 * scale) {
            Text("OBRÓĆ TRIKI = WYBÓR")
              .font(.system(size: 16 * scale, weight: .heavy, design: .monospaced))
              .foregroundStyle(NeonTheme.neonCyan)
            Text(payload.showPlayMenu ? "HOLD / PRZYCISK = START" : "HOLD / PRZYCISK = POTWIERDŹ KROK")
              .font(.system(size: 15 * scale, weight: .bold, design: .monospaced))
              .foregroundStyle(NeonTheme.neonYellow)
          }
        }
        .padding(40 * scale)
      }
    }
    .preferredColorScheme(.dark)
  }

  @ViewBuilder
  private func stepIndicator(payload: DartCalibrationTVPayload, scale: CGFloat) -> some View {
    HStack(spacing: 16 * scale) {
      stepDot(active: payload.step == .neutral, label: "1", scale: scale)
      stepDot(active: payload.step == .pullBack, label: "2", scale: scale)
      stepDot(active: payload.step == .pushForward || payload.step == .done, label: "3", scale: scale)
    }
  }

  private func stepDot(active: Bool, label: String, scale: CGFloat) -> some View {
    ZStack {
      Circle()
        .stroke(active ? NeonTheme.neonGreen : Color.white.opacity(0.25), lineWidth: 3 * scale)
        .frame(width: 44 * scale, height: 44 * scale)
      if active {
        Circle()
          .fill(NeonTheme.neonGreen.opacity(0.25))
          .frame(width: 44 * scale, height: 44 * scale)
      }
      Text(label)
        .font(.system(size: 16 * scale, weight: .heavy, design: .monospaced))
        .foregroundStyle(active ? NeonTheme.neonGreen : .white.opacity(0.5))
    }
  }

  private func progressRing(progress: Double, scale: CGFloat) -> some View {
    ZStack {
      Circle()
        .stroke(Color.white.opacity(0.15), lineWidth: 10 * scale)
        .frame(width: 120 * scale, height: 120 * scale)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(NeonTheme.neonCyan, style: StrokeStyle(lineWidth: 10 * scale, lineCap: .round))
        .frame(width: 120 * scale, height: 120 * scale)
        .rotationEffect(.degrees(-90))
      Text("\(Int(progress * 100))%")
        .font(.system(size: 28 * scale, weight: .black, design: .rounded))
        .foregroundStyle(NeonTheme.neonYellow)
    }
  }
}

// MARK: - Widok TV — Dart

struct DartTVView: View {
  @EnvironmentObject private var display: QuizExternalDisplay

  var body: some View {
    GeometryReader { geo in
      ZStack {
        dartTVBackdrop
        if !display.isExternalScreenConnected {
          dartWaitingCard(
            title: "DART TRIKI",
            subtitle: "Podłącz telewizor AirPlay lub HDMI",
            footnote: "Na telefonie włącz „Tarcza na telewizorze” i wybierz TV"
          )
        } else if !display.dartPayload.isDartActive {
          dartWaitingCard(
            title: "DART TRIKI",
            subtitle: "Gotowy do gry!",
            footnote: "Naciśnij GRAJ na telefonie · celuj nad tarczą · rzut = podnieś → w dół"
          )
        } else {
          dartTVGameLayer(size: geo.size, payload: display.dartPayload)
        }
      }
      .frame(width: geo.size.width, height: geo.size.height)
    }
    .preferredColorScheme(.dark)
    .ignoresSafeArea()
  }

  private var dartTVBackdrop: some View {
    ZStack {
      Color(red: 0.03, green: 0.04, blue: 0.10)
      RadialGradient(
        colors: [
          NeonTheme.neonCyan.opacity(0.08),
          NeonTheme.neonYellow.opacity(0.05),
          .clear
        ],
        center: .center,
        startRadius: 40,
        endRadius: max(500, 700)
      )
      LinearGradient(
        colors: [.black.opacity(0.5), .clear, .black.opacity(0.65)],
        startPoint: .leading,
        endPoint: .trailing
      )
    }
    .ignoresSafeArea()
  }

  private func dartTVGameLayer(size: CGSize, payload: DartTVPayload) -> some View {
    let crop = DartBoardLayout.tvCropRect
    let layout = PixelGridFitLayout.croppedUniform(source: crop, in: size)
    let tvScale = max(1.2, min(2.4, layout.scale / 8))
    let aimSize = max(56, layout.scale * 11)

    return ZStack {
      PixelCanvas(
        commands: payload.drawCommands,
        gridWidth: GameContext.width,
        gridHeight: GameContext.height,
        displayMode: .croppedUniform(source: crop)
      )
      .equatable()
      .frame(width: size.width, height: size.height)

      DartBoardMarkersOverlay(
        markers: payload.boardMarkers,
        layout: layout,
        markerSize: max(12, layout.scale * 2.2)
      )

      if payload.flightActive {
        DartFlyingDartView(
          progress: payload.flightProgress,
          diameter: max(32, layout.scale * 5)
        )
        .position(layout.point(gridX: payload.flightGridX, gridY: payload.flightGridY))
      } else {
        DartAimCircle(
          primed: payload.throwPrimed,
          feedbackLabel: payload.feedbackLabel,
          diameter: aimSize
        )
        .position(layout.point(gridX: payload.aimGridX, gridY: payload.aimGridY))
      }

      VStack {
        DartKinectTVScoreboard(
          playerNames: payload.playerNames,
          playerScores: payload.playerScores,
          activePlayerIndex: payload.activePlayerIndex,
          dartsLeftInTurn: payload.dartsLeftInTurn,
          gameOver: payload.gameOver,
          winnerName: payload.winnerName,
          scale: tvScale
        )
        .padding(.horizontal, 32)
        .padding(.top, 20)

        Spacer()

        if let feedback = payload.feedbackLabel {
          DartShotFeedbackCard(
            pointsLine: feedback,
            detailLine: payload.lastHitLabel,
            isMiss: feedback == "MISS",
            scale: tvScale * 1.35
          )
          .padding(.bottom, 48)
        }

        Text("PODNIEŚ RĘKĘ → PEŁNE KÓŁKO · RZUĆ W DÓŁ")
          .font(.system(size: 16 * tvScale, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonYellow.opacity(0.7))
          .tracking(1.5)
          .padding(.bottom, 28)
      }
      .frame(width: size.width, height: size.height)

      if let countdown = payload.startCountdown {
        DartStartCountdownOverlay(value: countdown, scale: tvScale * 1.35)
          .zIndex(40)
      }

      if let announcement = payload.turnAnnouncement {
        if payload.awaitingTurnStart {
          TrikiTurnConfirmBanner(playerName: announcement)
            .scaleEffect(tvScale * 1.15)
            .transition(.scale.combined(with: .opacity))
            .zIndex(35)
        } else {
          DartTurnChangeBanner(
            playerName: announcement,
            dartsLeft: payload.dartsLeftInTurn
          )
          .scaleEffect(tvScale * 1.15)
          .transition(.scale.combined(with: .opacity))
        }
      }
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.72), value: payload.turnAnnouncement)
    .animation(.easeOut(duration: 0.15), value: payload.startCountdown)
  }

  private func dartWaitingCard(title: String, subtitle: String, footnote: String) -> some View {
    let scale = max(1.2, min(2.0, UIScreen.main.bounds.width / 960))
    return VStack(spacing: 28 * scale) {
      Spacer()
      Text("◎")
        .font(.system(size: 48 * scale, weight: .black, design: .rounded))
        .foregroundStyle(NeonTheme.neonYellow)
      Text(title)
        .font(.system(size: 72 * scale, weight: .black, design: .rounded))
        .foregroundStyle(NeonTheme.neonYellow)
        .neonGlow(NeonTheme.neonYellow, radius: 12)
      Text(subtitle)
        .font(.system(size: 36 * scale, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
      Text(footnote)
        .font(.system(size: 24 * scale, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.55))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40 * scale)
      Spacer()
      Image(systemName: "tv.and.mediabox")
        .font(.system(size: 56 * scale, weight: .light))
        .foregroundStyle(NeonTheme.neonCyan.opacity(0.7))
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(32 * scale)
  }
}

// MARK: - Widok TV (teleturniej)

struct TVTypography {
  let scale: CGFloat
  let screenSize: CGSize

  init(size: CGSize) {
    screenSize = size
    let ref = min(size.width / 960, size.height / 540)
    scale = max(1.2, min(2.2, ref))
  }

  var title: CGFloat { 88 * scale }
  var subtitle: CGFloat { 40 * scale }
  var footnote: CGFloat { 28 * scale }
  var questionBase: CGFloat { 42 * scale }
  var answer: CGFloat { 34 * scale }
  var answerLetter: CGFloat { 40 * scale }
  var answerBadge: CGFloat { 80 * scale }
  var headerMeta: CGFloat { 24 * scale }
  var headerPlayer: CGFloat { 30 * scale }
  var headerQuestion: CGFloat { 42 * scale }
  var headerQuestionLabel: CGFloat { 18 * scale }
  var score: CGFloat { 46 * scale }
  var feedback: CGFloat { 72 * scale }
  var finishedTitle: CGFloat { 68 * scale }
  var footer: CGFloat { 20 * scale }
  var icon: CGFloat { 32 * scale }
  var contentPadding: CGFloat { 28 * scale }
  var answerSpacing: CGFloat { 18 * scale }

  /// Maks. wysokość bloku pytania — zostawia miejsce na odpowiedzi.
  var questionMaxHeight: CGFloat {
    screenSize.height * 0.24
  }

  /// Rozmiar czcionki pytania zależny od długości tekstu.
  func questionFont(for text: String) -> CGFloat {
    let length = text.count
    let factor: CGFloat
    switch length {
    case ..<45: factor = 1.0
    case ..<80: factor = 0.88
    case ..<120: factor = 0.76
    case ..<170: factor = 0.66
    case ..<230: factor = 0.56
    default: factor = 0.48
    }
    return questionBase * factor
  }
}

struct QuizTVView: View {
  @EnvironmentObject private var display: QuizExternalDisplay

  private let letters = ["A", "B", "C", "D"]
  private let answerColors: [Color] = [
    NeonTheme.neonOrange,
    NeonTheme.neonCyan,
    NeonTheme.neonGreen,
    NeonTheme.neonMagenta,
  ]

  var body: some View {
    GeometryReader { geo in
      let type = TVTypography(size: geo.size)
      let payload = display.payload
      ZStack {
        TVQuizBackdrop()
        TVQuizShowFrame(type: type) {
          if !display.isExternalScreenConnected {
            waitingCard(
              title: "QUIZ TRIKI",
              subtitle: "Podłącz telewizor AirPlay lub HDMI",
              footnote: "Na telefonie wybierz „Podłącz TV”",
              type: type
            )
          } else if !payload.isQuizActive {
            waitingCard(
              title: "QUIZ TRIKI",
              subtitle: "Gotowy do gry!",
              footnote: "Naciśnij START na telefonie · steruj Triki",
              type: type
            )
          } else if payload.isFinished {
            finishedCard(payload, type: type)
          } else {
            activeQuizCard(payload, type: type)
          }
        }
      }
    }
    .preferredColorScheme(.dark)
    .ignoresSafeArea()
  }

  private var tvBackdrop: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.02, green: 0.04, blue: 0.18),
          Color(red: 0.04, green: 0.02, blue: 0.12),
          Color.black,
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      RadialGradient(
        colors: [NeonTheme.neonCyan.opacity(0.14), .clear],
        center: .top,
        startRadius: 40,
        endRadius: 520
      )
      RadialGradient(
        colors: [NeonTheme.neonMagenta.opacity(0.08), .clear],
        center: .bottomTrailing,
        startRadius: 20,
        endRadius: 400
      )
    }
    .ignoresSafeArea()
  }

  private func showFrame<T: View>(type: TVTypography, @ViewBuilder content: () -> T) -> some View {
    content()
      .padding(.horizontal, type.contentPadding)
      .padding(.vertical, type.contentPadding * 0.85)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(
            LinearGradient(
              colors: [NeonTheme.neonYellow.opacity(0.85), NeonTheme.neonOrange.opacity(0.5), NeonTheme.neonCyan.opacity(0.4)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: max(4, type.scale * 2)
          )
      )
      .padding(type.contentPadding * 0.6)
  }

  private func waitingCard(title: String, subtitle: String, footnote: String, type: TVTypography) -> some View {
    VStack(spacing: type.contentPadding) {
      Spacer()
      Text("★")
        .font(.system(size: type.icon))
        .foregroundStyle(NeonTheme.neonYellow)
      Text(title)
        .font(.system(size: type.title, weight: .black, design: .rounded))
        .foregroundStyle(
          LinearGradient(
            colors: [NeonTheme.neonYellow, NeonTheme.neonOrange],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .neonGlow(NeonTheme.neonYellow, radius: 14)
        .minimumScaleFactor(0.7)
        .lineLimit(2)
      Text(subtitle)
        .font(.system(size: type.subtitle, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .minimumScaleFactor(0.8)
      Text(footnote)
        .font(.system(size: type.footnote, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.55))
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
      Spacer()
      Image(systemName: "tv.and.mediabox")
        .font(.system(size: type.title * 0.75, weight: .light))
        .foregroundStyle(NeonTheme.neonCyan.opacity(0.7))
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private func activeQuizCard(_ payload: QuizTVPayload, type: TVTypography) -> some View {
    VStack(spacing: 0) {
      tvHeader(payload, type: type)
        .padding(.bottom, type.contentPadding * 0.75)

      tvQuestionBlock(text: payload.questionText, type: type)
        .padding(.bottom, type.contentPadding * 0.85)

      if let feedback = payload.feedbackLabel {
        Text(feedback)
          .font(.system(size: type.feedback, weight: .black, design: .rounded))
          .foregroundStyle(feedback == "DOBRZE" ? NeonTheme.neonGreen : Color.red)
          .neonGlow(feedback == "DOBRZE" ? NeonTheme.neonGreen : .red, radius: 16)
          .frame(maxWidth: .infinity)
          .padding(.vertical, type.contentPadding)
      } else {
        VStack(spacing: type.answerSpacing) {
          ForEach(Array(payload.answers.enumerated()), id: \.offset) { offset, answer in
            TVQuizAnswerRow(
              letter: offset < letters.count ? letters[offset] : "?",
              text: answer,
              accent: offset < answerColors.count ? answerColors[offset] : NeonTheme.neonCyan,
              isSelected: payload.selectedIndex == offset,
              isHolding: payload.holdAnswerIndex == offset,
              holdProgress: payload.holdAnswerIndex == offset ? payload.holdProgress : 0,
              type: type
            )
          }
        }
      }

      Spacer(minLength: 8)

      Text("OBRÓT = WYBÓR · HOLD LUB PRZYCISK = OK")
        .font(.system(size: type.footer, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonYellow.opacity(0.75))
        .tracking(2)
        .frame(maxWidth: .infinity)
        .padding(.top, type.contentPadding * 0.5)
    }
  }

  private func tvQuestionBlock(text: String, type: TVTypography) -> some View {
    let fontSize = type.questionFont(for: text)
    return GeometryReader { geo in
      Text(text)
        .font(.system(size: fontSize, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .lineSpacing(type.scale * 3)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.38)
        .allowsTightening(true)
        .frame(width: geo.size.width, height: geo.size.height)
    }
    .frame(maxWidth: .infinity)
    .frame(height: type.questionMaxHeight)
    .padding(.horizontal, type.contentPadding * 0.65)
    .padding(.vertical, type.contentPadding * 0.45)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.white.opacity(0.06))
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(Color.white.opacity(0.15), lineWidth: 2)
        )
    )
  }

  private func tvHeader(_ payload: QuizTVPayload, type: TVTypography) -> some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 8) {
        Text(payload.roundLabel.uppercased())
          .font(.system(size: type.headerMeta, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonCyan)
        Text(payload.activePlayerName.uppercased())
          .font(.system(size: type.headerPlayer, weight: .black, design: .rounded))
          .foregroundStyle(NeonTheme.neonMagenta)
          .minimumScaleFactor(0.8)
          .lineLimit(1)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8) {
        Text("PYTANIE")
          .font(.system(size: type.headerQuestionLabel, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white.opacity(0.5))
        Text("\(payload.questionIndex) / \(payload.questionTotal)")
          .font(.system(size: type.headerQuestion, weight: .black, design: .rounded))
          .foregroundStyle(NeonTheme.neonYellow)
      }
      scoreBadge(payload, type: type, large: true)
        .padding(.leading, type.contentPadding * 0.75)
    }
  }

  private func finishedCard(_ payload: QuizTVPayload, type: TVTypography) -> some View {
    VStack(spacing: type.contentPadding) {
      Spacer()
      Text("KONIEC RUNDY")
        .font(.system(size: type.finishedTitle, weight: .black, design: .rounded))
        .foregroundStyle(NeonTheme.neonGreen)
        .neonGlow(NeonTheme.neonGreen, radius: 12)
      scoreBadge(payload, type: type, large: true)
        .scaleEffect(1.35)
      Spacer()
    }
  }

  @ViewBuilder
  private func scoreBadge(_ payload: QuizTVPayload, type: TVTypography, large: Bool = false) -> some View {
    let fontSize = large ? type.score : type.score * 0.72
    HStack(spacing: 14) {
      Text("\(payload.player1Score)")
        .font(.system(size: fontSize, weight: .black, design: .rounded))
        .foregroundStyle(NeonTheme.neonYellow)
      if payload.mode == .duo {
        Text(":")
          .font(.system(size: fontSize * 0.7, weight: .bold))
          .foregroundStyle(.white.opacity(0.45))
        Text("\(payload.player2Score)")
          .font(.system(size: fontSize, weight: .black, design: .rounded))
          .foregroundStyle(NeonTheme.neonYellow)
      }
    }
    .padding(.horizontal, large ? type.contentPadding * 0.65 : 12)
    .padding(.vertical, large ? type.contentPadding * 0.4 : 8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.black.opacity(0.45))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(NeonTheme.neonYellow.opacity(0.6), lineWidth: 2)
        )
    )
  }

  private func tvAnswerRow(
    letter: String,
    text: String,
    accent: Color,
    isSelected: Bool,
    isHolding: Bool,
    holdProgress: Double,
    type: TVTypography
  ) -> some View {
    HStack(spacing: type.contentPadding * 0.65) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [accent, accent.opacity(0.65)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: type.answerBadge, height: type.answerBadge)
          .overlay(
            Circle()
              .stroke(Color.white.opacity(isSelected ? 0.9 : 0.35), lineWidth: isSelected ? 4 : 2)
          )
        if isHolding {
          Circle()
            .trim(from: 0, to: holdProgress)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .frame(width: type.answerBadge * 1.15, height: type.answerBadge * 1.15)
            .rotationEffect(.degrees(-90))
        }
        Text(letter)
          .font(.system(size: type.answerLetter, weight: .black, design: .rounded))
          .foregroundStyle(.white)
      }

      Text(text)
        .font(.system(size: type.answer, weight: isSelected ? .bold : .semibold, design: .rounded))
        .foregroundStyle(.white)
        .lineSpacing(type.scale * 4)
        .minimumScaleFactor(0.88)
        .frame(maxWidth: .infinity, alignment: .leading)

      if isSelected || isHolding {
        Image(systemName: isHolding ? "hand.tap.fill" : "checkmark.circle.fill")
          .font(.system(size: type.answer * 0.9, weight: .bold))
          .foregroundStyle(isHolding ? NeonTheme.neonMagenta : accent)
      }
    }
    .padding(.horizontal, type.contentPadding * 0.75)
    .padding(.vertical, type.contentPadding * 0.55)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(isSelected || isHolding ? accent.opacity(0.18) : Color.white.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(
          isHolding ? NeonTheme.neonMagenta : (isSelected ? accent.opacity(0.85) : Color.white.opacity(0.14)),
          lineWidth: isHolding ? 5 : (isSelected ? 4 : 2)
        )
    )
    .scaleEffect(isSelected ? 1.02 : 1)
    .animation(.easeOut(duration: 0.2), value: isSelected)
  }
}
