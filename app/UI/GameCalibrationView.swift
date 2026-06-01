import Combine
import SwiftUI
import VeltoKit

private let calibrationRefreshInterval = 0.15

/// Tworzy sesje tylko dla gry, która ich potrzebuje (Pong nie inicjuje DartSession).
@MainActor
private final class GameLobbySessions: ObservableObject {
  let dart: DartSession?
  let bowling: BowlingSession?

  init(gameType: GameType) {
    dart = gameType == .dart ? DartSession() : nil
    bowling = gameType == .bowling ? BowlingSession() : nil
  }
}

struct GameCalibrationView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var inputProvider: MotionInputProvider
  @EnvironmentObject private var tuning: GameTuning
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay

  let gameType: GameType
  var quizQuestions: [Question] = []
  var quizSession: QuizSession?

  @StateObject private var sessions: GameLobbySessions
  @State private var startGame = false
  @State private var startDartCalibration = false
  @AppStorage(ArcadeTVSettings.dartBoardOnTVKey) private var dartBoardOnTV = false
  @AppStorage(ArcadeTVSettings.bowlingOnTVKey) private var bowlingOnTV = false
  @AppStorage(ArcadeSettings.keepScreenOnDuringPlayKey) private var keepScreenOnDuringPlay = true
  @AppStorage(ArcadeSettings.backgroundMusicEnabledKey) private var backgroundMusicEnabled = false
  @State private var dartMenuPage = 0

  init(gameType: GameType, quizQuestions: [Question] = [], quizSession: QuizSession? = nil) {
    self.gameType = gameType
    self.quizQuestions = quizQuestions
    self.quizSession = quizSession
    _sessions = StateObject(wrappedValue: GameLobbySessions(gameType: gameType))
  }

  /// Tylko w lobby Dart — przy `gameType == .dart` sesja zawsze istnieje.
  private var dartSession: DartSession {
    guard let dart = sessions.dart else {
      preconditionFailure("dartSession requested outside dart lobby")
    }
    return dart
  }

  /// Tylko w lobby Bowling — przy `gameType == .bowling` sesja zawsze istnieje.
  private var bowlingSession: BowlingSession {
    guard let bowling = sessions.bowling else {
      preconditionFailure("bowlingSession requested outside bowling lobby")
    }
    return bowling
  }

  private var dartTrikiNavigationActive: Bool {
    gameType == .dart && !startGame && !startDartCalibration
  }

  private var bowlingTrikiNavigationActive: Bool {
    gameType == .bowling && !startGame
  }

  private var lobbyKeepsScreenAwake: Bool {
    (gameType == .dart || gameType == .bowling)
      && keepScreenOnDuringPlay
      && !startGame
      && (gameType != .dart || !startDartCalibration)
  }

  private var lobbyMusic: ArcadePlaySessionModifier.ArcadePlayMusic {
    switch gameType {
    case .dart: return .dartLobby
    case .bowling: return .bowlingLobby
    default: return .none
    }
  }

  /// Przy podłączonym TV sterowanie Triki tylko na ekranie telewizora (telefon = dotyk).
  private var dartTrikiPhoneHUD: Bool {
    !quizDisplay.isExternalScreenConnected
  }

  var body: some View {
    Group {
      if gameType == .dart {
        dartTVLobbyBody
          .trikiUIScreen(
            itemCount: DartLobbyTVLayout.trikiSlotCount,
            isActive: dartTrikiNavigationActive,
            showsPhoneHUD: dartTrikiPhoneHUD
          ) { handleDartLobbyMenuSlot($0) }
      } else if gameType == .bowling {
        bowlingLobbyBody
          .trikiUIScreen(itemCount: 3, isActive: bowlingTrikiNavigationActive) { slot in
            handleBowlingLobbySlot(slot)
          }
      } else {
        legacyCalibrationBody
      }
    }
    .navigationTitle("Kalibracja")
    .navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .fullScreenCover(isPresented: $startDartCalibration) {
      if let dartSession = sessions.dart {
        NavigationStack {
          DartCalibrationFlowView(
            session: dartSession,
            inputProvider: inputProvider,
            onFinished: {
              startDartCalibration = false
              beginGameAfterCalibration()
            }
          )
        }
      }
    }
    .fullScreenCover(isPresented: $startGame) {
      gameFullScreenCover
        .environmentObject(inputProvider)
        .environmentObject(trikiUI)
        .environmentObject(quizDisplay)
    }
    .onChange(of: quizSession?.phase) { _, phase in
      guard gameType == .quiz else { return }
      if phase == .categoryPick || phase == .finished || phase == .lobby {
        startGame = false
      }
    }
    .onAppear {
      if gameType == .dart {
        GameManager.applyUIMode(to: inputProvider)
        if !inputProvider.isConnected {
          inputProvider.connect()
        }
        quizDisplay.setDartLobbyActive(true)
        syncDartLobbyToTV()
      } else if gameType == .bowling {
        GameManager.applyUIMode(to: inputProvider)
        if !inputProvider.isConnected {
          inputProvider.connect()
        }
        if bowlingOnTV || quizDisplay.isExternalScreenConnected {
          quizDisplay.setBowlingLobbyActive(true)
          syncBowlingLobbyToTV()
        }
      } else {
        GameManager.applyMotionMode(gameType: gameType, to: inputProvider)
      }
    }
    .onDisappear {
      if gameType == .dart, !startGame {
        quizDisplay.setDartLobbyActive(false)
        GameManager.applyUIMode(to: inputProvider)
      }
      if gameType == .bowling, !startGame {
        trikiUI.clear()
        quizDisplay.setBowlingLobbyActive(false)
      }
    }
    .onChange(of: trikiUI.focusIndex) { _, _ in
      if gameType == .dart { syncDartLobbyToTV() }
    }
    .onChange(of: trikiUI.holdProgress) { _, _ in
      if gameType == .dart { syncDartLobbyToTV() }
    }
    .onChange(of: sessions.dart?.mode) { _, _ in
      if gameType == .dart { syncDartLobbyToTV() }
    }
    .onChange(of: dartBoardOnTV) { _, _ in
      if gameType == .dart { syncDartLobbyToTV() }
    }
    .onChange(of: keepScreenOnDuringPlay) { _, _ in
      if gameType == .dart { syncDartLobbyToTV() }
    }
    .onChange(of: dartMenuPage) { _, _ in
      if gameType == .dart {
        trikiUI.clearFocus()
        syncDartLobbyToTV()
      }
    }
    .onChange(of: bowlingOnTV) { _, _ in
      if gameType == .bowling { syncBowlingLobbyToTV() }
    }
    .onChange(of: quizDisplay.isExternalScreenConnected) { _, connected in
      if gameType == .bowling {
        if connected, bowlingOnTV {
          quizDisplay.setBowlingLobbyActive(true)
        }
        syncBowlingLobbyToTV()
      }
      guard gameType == .dart else { return }
      if quizDisplay.isExternalScreenConnected {
        trikiUI.clearFocus()
      }
      syncDartLobbyToTV()
    }
    .arcadePlaySession(
      active: lobbyKeepsScreenAwake && !startGame && !startDartCalibration,
      music: lobbyMusic
    )
    .background {
      if !startGame, gameType != .dart {
        TimelineView(.periodic(from: .now, by: calibrationRefreshInterval)) { timeline in
          Color.clear
            .onChange(of: timeline.date.timeIntervalSinceReferenceDate, initial: true) { _, _ in
              _ = inputProvider.pollInput()
            }
        }
      }
    }
  }

  private var hasMotionSignal: Bool {
    inputProvider.isReceiving || inputProvider.isConnected
  }

  // MARK: - Dart · TV + Triki

  private var dartTVLobbyBody: some View {
    ZStack {
      ArcadeUI.screenBackground
      ScrollView(showsIndicators: false) {
        VStack(spacing: 14) {
          DartPhoneTVCompanion(
            inputProvider: inputProvider,
            tvConnected: quizDisplay.isExternalScreenConnected,
            title: quizDisplay.isExternalScreenConnected ? "MENU NA TELEWIZORZE" : "DART · TRIKI",
            subtitle: quizDisplay.isExternalScreenConnected
              ? "Triki działa tylko na TV · opcje poniżej — dotyk na telefonie"
              : "Gra i menu na telefonie · opcjonalnie TV (AirPlay)"
          )

          dartPhoneActionsSection
          dartModeSection
          dartTVSection
          dartCalibrationInfo

          if dartSession.canResumeMatch, let summary = dartSession.savedMatch?.resumeSummary {
            ArcadeUI.panel {
              Text(summary)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(NeonTheme.neonYellow.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }

          if !quizDisplay.isExternalScreenConnected {
            TVConnectPanel(hint: "Podłącz TV (AirPlay) — menu i gra na dużym ekranie")
          }

          ArcadeUI.secondaryButton("WSTECZ", tint: .white.opacity(0.7)) {
            quizDisplay.setDartLobbyActive(false)
            dismiss()
          }
        }
        .padding(16)
      }
    }
  }

  private var dartPhoneActionsSection: some View {
    VStack(spacing: 10) {
      ArcadeUI.sectionLabel("OPCJE (TELEFON)")

      if dartSession.canResumeMatch {
        ArcadeUI.primaryButton("KONTYNUUJ GRĘ", icon: "play.fill") {
          beginGameAfterCalibration()
        }
        ArcadeUI.secondaryButton("NOWA GRA", tint: NeonTheme.neonMagenta) {
          beginNewDartGame()
        }
      } else {
        ArcadeUI.primaryButton("ROZPOCZNIJ GRĘ", icon: "play.fill") {
          beginGameAfterCalibration()
        }
      }

      ArcadeUI.secondaryButton("KALIBRACJA TRIKI", tint: NeonTheme.neonCyan) {
        quizDisplay.setDartLobbyActive(false)
        startDartCalibration = true
      }

      let axes = inputProvider.config.axisMapping
      HStack(spacing: 10) {
        ArcadeUI.secondaryButton(
          axes.invertX ? "ODWRÓĆ X ✓" : "ODWRÓĆ X",
          tint: axes.invertX ? NeonTheme.neonGreen : .white.opacity(0.75)
        ) {
          var a = inputProvider.config.axisMapping
          a.invertX.toggle()
          inputProvider.config.axisMapping = a
          DartLobbySettings.saveAxisMapping(a)
          syncDartLobbyToTV()
        }

        ArcadeUI.secondaryButton(
          axes.invertY ? "ODWRÓĆ Y ✓" : "ODWRÓĆ Y",
          tint: axes.invertY ? NeonTheme.neonGreen : .white.opacity(0.75)
        ) {
          var a = inputProvider.config.axisMapping
          a.invertY.toggle()
          inputProvider.config.axisMapping = a
          DartLobbySettings.saveAxisMapping(a)
          syncDartLobbyToTV()
        }
      }
    }
  }

  private var bowlingLobbyBody: some View {
    ZStack {
      ArcadeUI.screenBackground
      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          DartPhoneTVCompanion(
            inputProvider: inputProvider,
            tvConnected: quizDisplay.isExternalScreenConnected,
            title: quizDisplay.isExternalScreenConnected ? "BOWLING NA TELEWIZORZE" : "BOWLING · TRIKI",
            subtitle: quizDisplay.isExternalScreenConnected
              ? "Tor 3D na TV · telefon = pilot Triki"
              : "Pełny tor 3D na telefonie · TV opcjonalnie (AirPlay)"
          )

          Text("Bowling 3D")
            .font(.system(size: 22, weight: .heavy, design: .monospaced))
            .foregroundStyle(Color.orange)
          instructionBlock
          bowlingLobbySection
          bowlingTVSection
          backgroundMusicToggle
          pointerMeter
          presetReadout
          debugReadout
          statusLine
          TrikiFocusRow(index: 0, title: "GRAJ", subtitle: "Start rozgrywki", accent: Color.orange, icon: "play.fill")
          TrikiFocusRow(index: 1, title: "ZMIEŃ TRYB", subtitle: nextBowlingModeLabel, accent: NeonTheme.neonMagenta, icon: "person.2.fill")
          TrikiFocusRow(index: 2, title: "WSTECZ", subtitle: "Menu główne", accent: .white.opacity(0.7), icon: "arrow.left")
          ArcadeUI.primaryButton("GRAJ", icon: "play.fill") { beginGameAfterCalibration() }
          ArcadeUI.secondaryButton("WSTECZ", tint: .white.opacity(0.7)) { dismiss() }

          if bowlingOnTV, !quizDisplay.isExternalScreenConnected {
            TVConnectPanel(hint: "Włączono tor na TV — podłącz AirPlay, by zobaczyć tor na telewizorze")
          }
        }
        .padding(16)
      }
    }
    .background {
      TimelineView(.periodic(from: .now, by: calibrationRefreshInterval)) { timeline in
        Color.clear
          .onChange(of: timeline.date.timeIntervalSinceReferenceDate, initial: true) { _, _ in
            _ = inputProvider.pollInput()
          }
      }
    }
  }

  @ViewBuilder
  private var gameFullScreenCover: some View {
    switch gameType {
    case .quiz:
      if let quizSession {
        QuizGameView(
          session: quizSession,
          inputProvider: inputProvider,
          tuning: tuning
        )
      } else {
        Color.black.ignoresSafeArea()
      }
    case .dart:
      if let dartSession = sessions.dart {
        DartGameView(session: dartSession, inputProvider: inputProvider, tuning: tuning)
      }
    case .bowling:
      if let bowlingSession = sessions.bowling {
        BowlingGameView(session: bowlingSession, inputProvider: inputProvider, tuning: tuning)
      }
    default:
      GameView(gameType: gameType, inputProvider: inputProvider, tuning: tuning)
    }
  }

  private func handleBowlingLobbySlot(_ slot: Int) {
    guard let bowlingSession = sessions.bowling else { return }
    switch slot {
    case 0: beginGameAfterCalibration()
    case 1: bowlingSession.cycleMode()
    case 2: dismiss()
    default: break
    }
  }

  @ViewBuilder
  private var bowlingLobbySection: some View {
    if let bowlingSession = sessions.bowling {
      BowlingLobbySectionView(session: bowlingSession, nextModeLabel: nextBowlingModeLabel)
    }
  }

  private var nextBowlingModeLabel: String {
    guard let mode = sessions.bowling?.mode else { return "—" }
    switch mode {
    case .solo: return "2 graczy"
    case .duo: return "3 graczy"
    case .trio: return "4 graczy"
    case .quad: return "1 gracz"
    }
  }

  private var bowlingLobby: some View {
    bowlingLobbySection
  }

  private var legacyCalibrationBody: some View {
    ZStack {
      ArcadeUI.screenBackground
      ScrollView(showsIndicators: false) {
        VStack(spacing: 12) {
          Text("Kalibracja")
            .font(.system(size: 22, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonCyan)
          Text(gameType.rawValue.uppercased())
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
          instructionBlock
          if gameType == .bowling { bowlingLobby }
          if gameType != .dart { pointerMeter }
          if gameType == .quiz { answerZonesHint }
          presetReadout
          if gameType == .pong || gameType == .bowling { debugReadout }
          statusLine
          ArcadeUI.primaryButton("GRAJ", icon: "play.fill") { beginGameAfterCalibration() }
          ArcadeUI.secondaryButton("WSTECZ", tint: .white.opacity(0.7)) { dismiss() }
        }
        .padding(16)
      }
    }
  }

  private func syncDartLobbyToTV() {
    guard let dartSession = sessions.dart else { return }
    let axes = inputProvider.config.axisMapping
    var state = quizDisplay.dartLobbyPayload
    state.menuPage = dartMenuPage
    state.focusIndex = trikiUI.focusIndex
    state.holdProgress = trikiUI.holdProgress
    state.playerCount = dartSession.playerCount
    state.playerNames = (0 ..< dartSession.playerCount).map { dartSession.name(at: $0) }
    state.player1Name = dartSession.player1Name
    state.player2Name = dartSession.player2Name
    state.mode = dartSession.mode
    state.dartBoardOnTV = dartBoardOnTV
    state.keepScreenOn = keepScreenOnDuringPlay
    state.canResume = dartSession.canResumeMatch
    state.resumeSummary = dartSession.savedMatch?.resumeSummary
    state.profileP1Ready = DartPlayerProfileStore.player1?.isComplete == true
    state.profileP2Ready = DartPlayerProfileStore.player2?.isComplete == true
    state.invertX = axes.invertX
    state.invertY = axes.invertY
    state.hasTriki = inputProvider.isTrikiControlAvailable
    quizDisplay.updateDartLobby(state)
  }

  private func handleDartLobbyMenuSlot(_ slot: Int) {
    let choices = DartLobbyTVLayout.choicesWithBack(
      page: dartMenuPage,
      payload: quizDisplay.dartLobbyPayload
    )
    guard slot >= 0, slot < choices.count else { return }
    let choice = choices[slot]
    if let navigation = choice.navigation {
      switch navigation {
      case .openOptions:
        dartMenuPage = 1
      case .openMain:
        dartMenuPage = 0
      }
      trikiUI.clearFocus()
      syncDartLobbyToTV()
      return
    }
    guard let item = choice.menuItem else { return }
    handleDartLobbyMenu(item.rawValue)
  }

  private func handleDartLobbyMenu(_ index: Int) {
    guard let item = DartLobbyMenuItem(rawValue: index) else { return }
    switch item {
    case .play:
      beginGameAfterCalibration()
    case .newGame:
      beginNewDartGame()
    case .calibrate:
      quizDisplay.setDartLobbyActive(false)
      startDartCalibration = true
    case .toggleMode:
      dartSession.toggleMode()
      syncDartLobbyToTV()
    case .toggleTVBoard:
      dartBoardOnTV.toggle()
      syncDartLobbyToTV()
    case .invertX:
      var axes = inputProvider.config.axisMapping
      axes.invertX.toggle()
      inputProvider.config.axisMapping = axes
      DartLobbySettings.saveAxisMapping(axes)
      syncDartLobbyToTV()
    case .invertY:
      var axes = inputProvider.config.axisMapping
      axes.invertY.toggle()
      inputProvider.config.axisMapping = axes
      DartLobbySettings.saveAxisMapping(axes)
      syncDartLobbyToTV()
    case .toggleKeepAwake:
      applyKeepScreenOnSetting(!keepScreenOnDuringPlay)
      syncDartLobbyToTV()
    case .back:
      quizDisplay.setDartLobbyActive(false)
      dismiss()
    }
  }

  private func applyKeepScreenOnSetting(_ enabled: Bool) {
    keepScreenOnDuringPlay = enabled
    ArcadeSettings.keepScreenOnDuringPlay = enabled
    if !enabled {
      ScreenAwake.releaseAll()
    } else {
      ScreenAwake.apply()
    }
  }

  private func beginNewDartGame() {
    dartSession.clearSavedMatch()
    beginGameAfterCalibration()
  }

  private func beginGameAfterCalibration() {
    if gameType == .dart {
      GameManager.applyMotionMode(gameType: .dart, to: inputProvider)
      if hasMotionSignal {
        inputProvider.motionSDK.engine.resetGestureBaseline()
      }
    } else if gameType == .bowling {
      GameManager.applyMotionMode(gameType: .bowling, to: inputProvider)
      if hasMotionSignal {
        inputProvider.motionSDK.engine.resetGestureBaseline()
      }
    } else if hasMotionSignal {
      inputProvider.motionSDK.engine.resetPaddleMotion()
    }
    if gameType == .dart {
      quizDisplay.setDartLobbyActive(false)
    }
    if gameType == .bowling {
      quizDisplay.setBowlingLobbyActive(false)
    }
    quizSession?.startPlaying()
    startGame = true
  }

  private var dartCalibrationInfo: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Kalibracja na TV + Triki")
        .font(.system(size: 12, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonCyan)
      Text("Każdy gracz: neutral (cel) → podnieś rękę (próg) → rzut w dół (moc)")
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.65))
      dartProfileStatusLines
      Text(DartPlayZone.distanceExplanation)
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.45))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.white.opacity(0.06))
  }

  @ViewBuilder
  private var dartProfileStatusLines: some View {
    let calibrated = (0 ..< dartSession.playerCount).filter {
      DartPlayerProfileStore.profile(for: $0)?.isComplete == true
    }
    if !calibrated.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(calibrated, id: \.self) { index in
          Text("✓ \(dartSession.name(at: index)): cel, odległość, cofanie, moc rzutu")
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(NeonTheme.neonGreen)
        }
        if calibrated.count < dartSession.playerCount {
          Text("Pozostali gracze: użyj kalibracji (profil na gracza)")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
        }
      }
    } else {
      Text("Brak kalibracji — użyj KALIBRACJA TRIKI przed pierwszą grą")
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(NeonTheme.neonOrange)
    }
  }

  @ViewBuilder
  private var instructionBlock: some View {
    if gameType == .quiz {
      VStack(alignment: .leading, spacing: 6) {
        Text("1. Obrót Triki — wybór A–D")
        Text("2. Hold lub przycisk Triki — zatwierdź")
      }
    } else if gameType == .dart {
      VStack(alignment: .leading, spacing: 6) {
        Text("1. Trzymaj Triki nad tarczą, skierowany w dół (rzut od góry)")
        Text("2. Stań w wygodnej odległości — zapisz ją holdem Triki")
        Text("3. Cel: przesuń lewo/prawo i przód/tył · rzut: podnieś rękę → rzuć w dół")
        Text("4. Zły kierunek? ODWRÓĆ LEWO/PRAWO lub GÓRA/DÓŁ (cel)")
        Text("5. Wybierz 1–8 graczy — na zmianę po 3 lotkach")
        Text("6. GRAJ")
        if dartBoardOnTV {
          Text("7. Włącz „Tarcza na telewizorze” — duża tarcza na TV")
            .foregroundStyle(NeonTheme.neonYellow.opacity(0.9))
        }
      }
      .font(.system(size: 12, design: .monospaced))
      .foregroundStyle(.white.opacity(0.85))
      .frame(maxWidth: .infinity, alignment: .leading)
    } else if gameType == .bowling {
      VStack(alignment: .leading, spacing: 6) {
        Text("1. Pochyl Triki lewo/prawo — celuj kulą")
        Text("2. Cofnij rękę → mocno do przodu — rzut")
        Text("3. 10 frame’ów · strike / spare · do 4 graczy")
        Text("4. Dotknij GRAJ")
      }
      .font(.system(size: 12, design: .monospaced))
      .foregroundStyle(.white.opacity(0.85))
      .frame(maxWidth: .infinity, alignment: .leading)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Text("1. Pochyl — paletka w grze")
        Text("2. Dotknij „GRAJ” — start")
      }
      .font(.system(size: 12, design: .monospaced))
      .foregroundStyle(.white.opacity(0.9))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(Color.white.opacity(0.06))
    }
  }

  private var pointerMeter: some View {
    let posX = inputProvider.liveInput.posX
    let magnitude = min(abs(posX), 1)
    let selection = quizSelectionLabel(posX: posX)

    return VStack(spacing: 8) {
      HStack {
        Text("POS X \(String(format: "%+.2f", posX))")
          .font(.system(size: 13, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)
        Spacer()
        if gameType == .quiz {
          Text("→ \(selection)")
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonMagenta)
        }
      }

      GeometryReader { geo in
        let center = geo.size.width / 2
        let barWidth = geo.size.width * magnitude
        ZStack(alignment: .leading) {
          Rectangle()
            .fill(Color.white.opacity(0.1))
          if gameType == .quiz {
            ForEach(0..<4, id: \.self) { slot in
              Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: geo.size.width / 4)
                .offset(x: geo.size.width * CGFloat(slot) / 4)
            }
          }
          if posX < 0 {
            Rectangle()
              .fill(NeonTheme.neonCyan)
              .frame(width: barWidth)
              .offset(x: center - barWidth)
          } else if posX > 0 {
            Rectangle()
              .fill(NeonTheme.neonCyan)
              .frame(width: barWidth)
              .offset(x: center)
          }
          Rectangle()
            .fill(NeonTheme.neonMagenta)
            .frame(width: 2)
            .offset(x: center - 1)
        }
      }
      .frame(height: 28)
    }
  }

  private var answerZonesHint: some View {
    Text("Obrót → A–D · hold lub przycisk = OK")
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      .foregroundStyle(.white.opacity(0.55))
      .multilineTextAlignment(.center)
  }

  private func quizSelectionLabel(posX: Double) -> String {
    let labels = ["A", "B", "C", "D"]
    let index = TrikiUIMath.focusedSlot(posX: posX, slots: 4) ?? 0
    guard labels.indices.contains(index) else { return "?" }
    return labels[index]
  }

  private var presetReadout: some View {
    let cfg = inputProvider.config
    return VStack(alignment: .leading, spacing: 4) {
      Text("TRYB \(cfg.mode.rawValue.uppercased())")
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonCyan.opacity(0.9))
      Text("deadzone \(String(format: "%.3f", cfg.deadzone))")
    }
    .font(.system(size: 10, design: .monospaced))
    .foregroundStyle(.white.opacity(0.65))
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 6)
  }

  private var debugReadout: some View {
    let dbg = inputProvider.motionSDK.debug
    return Text("\(dbg.paddleDirection) · pos \(String(format: "%+.2f", inputProvider.liveInput.posX))")
      .font(.system(size: 11, weight: .bold, design: .monospaced))
      .foregroundStyle(NeonTheme.neonYellow)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var dartModeSection: some View {
    VStack(spacing: 10) {
      ArcadeUI.panel {
        VStack(alignment: .leading, spacing: 10) {
          ArcadeUI.sectionLabel("LICZBA GRACZY · \(dartSession.playerCount)")
          Text("501 · na zmianę · 3 lotki na turę · max \(DartPlayers.maxCount)")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))

          HStack(spacing: 12) {
            ArcadeUI.secondaryButton("−", tint: .white.opacity(0.75)) {
              if dartSession.playerCount > DartPlayers.minCount {
                let next = dartSession.playerCount - 1
                if dartSession.savedMatch?.playerCount != next {
                  dartSession.clearSavedMatch()
                }
                dartSession.playerCount = next
                dartSession.persistLobbyPreferences()
                syncDartLobbyToTV()
              }
            }
            .disabled(dartSession.playerCount <= DartPlayers.minCount)

            Text("\(dartSession.playerCount)")
              .font(.system(size: 22, weight: .black, design: .rounded))
              .foregroundStyle(NeonTheme.neonYellow)
              .frame(minWidth: 36)

            ArcadeUI.secondaryButton("+", tint: NeonTheme.neonMagenta) {
              if dartSession.playerCount < DartPlayers.maxCount {
                let next = dartSession.playerCount + 1
                if dartSession.savedMatch?.playerCount != next {
                  dartSession.clearSavedMatch()
                }
                dartSession.playerCount = next
                dartSession.persistLobbyPreferences()
                syncDartLobbyToTV()
              }
            }
            .disabled(dartSession.playerCount >= DartPlayers.maxCount)
          }
        }
      }

      ArcadeUI.panel {
        VStack(alignment: .leading, spacing: 10) {
          ArcadeUI.sectionLabel("IMIONA")
          ForEach(0 ..< dartSession.playerCount, id: \.self) { index in
            TextField(DartPlayers.defaultName(index: index), text: dartPlayerNameBinding(index))
              .textFieldStyle(.roundedBorder)
          }
        }
      }

      ArcadeUI.secondaryButton(
        "PRZEŁĄCZ LICZBĘ (1…\(DartPlayers.maxCount))",
        tint: NeonTheme.neonMagenta
      ) {
        dartSession.cyclePlayerCount()
        syncDartLobbyToTV()
      }
    }
  }

  private func dartPlayerNameBinding(_ index: Int) -> Binding<String> {
    Binding(
      get: { dartSession.name(at: index) },
      set: { newValue in
        dartSession.setName(newValue, at: index)
        dartSession.persistLobbyPreferences()
        syncDartLobbyToTV()
      }
    )
  }

  private func syncBowlingLobbyToTV() {
    guard gameType == .bowling else { return }
    if bowlingOnTV || quizDisplay.isExternalScreenConnected {
      if !quizDisplay.bowlingLobbyPayload.isActive, !startGame {
        quizDisplay.setBowlingLobbyActive(true)
      }
      quizDisplay.updateBowlingLobby(
        modeTitle: sessions.bowling?.mode.title ?? "Bowling",
        playerNames: sessions.bowling?.playerNames ?? []
      )
    } else {
      quizDisplay.setBowlingLobbyActive(false)
    }
  }

  private var bowlingTVSection: some View {
    VStack(spacing: 10) {
      Toggle(isOn: $bowlingOnTV) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Tor na telewizorze")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
          Text("Tor na dużym ekranie (AirPlay) · bez TV gra na telefonie")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.5))
        }
      }
      .tint(Color.orange)
      .onChange(of: bowlingOnTV) { _, _ in syncBowlingLobbyToTV() }

      if bowlingOnTV {
        TVConnectPanel(
          hint: "Podłącz TV przed grą · tor i wyniki na ekranie telewizora"
        )
      }
    }
    .padding(12)
    .background(Color.white.opacity(0.06))
  }

  private var dartTVSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Toggle(isOn: $dartBoardOnTV) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Tarcza na telewizorze")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
          Text("Tarcza na TV (AirPlay) · bez TV gra na ekranie telefonu")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
        }
      }
      .tint(NeonTheme.neonYellow)

      if dartBoardOnTV {
        TVConnectPanel(
          hint: "Podłącz TV przed grą · tarcza i wynik na ekranie telewizora"
        )
      }

      Toggle(isOn: $keepScreenOnDuringPlay) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Nie wyłączaj ekranu w grze")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
          Text("Telefon nie gaśnie podczas rozgrywki i kalibracji")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
        }
      }
      .tint(NeonTheme.neonGreen)
      .onChange(of: keepScreenOnDuringPlay) { _, enabled in
        applyKeepScreenOnSetting(enabled)
        syncDartLobbyToTV()
      }

      backgroundMusicToggle
    }
  }

  private var backgroundMusicToggle: some View {
    Toggle(isOn: $backgroundMusicEnabled) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Muzyka w tle")
          .font(.system(size: 14, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white)
        Text("Chiptune w Dart · domyślnie wyłączone")
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.6))
      }
    }
    .tint(NeonTheme.neonMagenta)
    .onChange(of: backgroundMusicEnabled) { _, enabled in
      ArcadeSettings.backgroundMusicEnabled = enabled
      if !enabled { ArcadeAudio.stopMusic() }
    }
  }

  private var statusLine: some View {
    let text: String
    if gameType == .dart {
      text = hasMotionSignal
        ? "KALIBRACJA TRIKI — instrukcje na TV · każdy gracz osobno"
        : "Podłącz Triki · kalibracja przed grą"
    } else {
      text = hasMotionSignal
        ? "Triki gotowy — dotknij „GRAJ”"
        : "Bez BLE — możesz grać i używać UI"
    }
    let color: Color = hasMotionSignal ? NeonTheme.neonGreen : NeonTheme.neonOrange
    return Text(text)
      .font(.system(size: 11, weight: .bold, design: .monospaced))
      .foregroundStyle(color)
      .multilineTextAlignment(.center)
  }
}

private struct BowlingLobbySectionView: View {
  @ObservedObject var session: BowlingSession
  let nextModeLabel: String

  var body: some View {
    VStack(spacing: 10) {
      ArcadeUI.panel {
        VStack(alignment: .leading, spacing: 8) {
          ArcadeUI.sectionLabel("TRYB · \(session.mode.title)")
          Text("Na zmianę · 10 frame’ów · strike / spare")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
        }
      }

      ArcadeUI.panel {
        VStack(alignment: .leading, spacing: 10) {
          ArcadeUI.sectionLabel("GRACZE")
          TextField("Gracz 1", text: $session.player1Name)
            .textFieldStyle(.roundedBorder)
          if session.mode == .duo || session.mode == .trio || session.mode == .quad {
            TextField("Gracz 2", text: $session.player2Name)
              .textFieldStyle(.roundedBorder)
          }
          if session.mode == .trio || session.mode == .quad {
            TextField("Gracz 3", text: $session.player3Name)
              .textFieldStyle(.roundedBorder)
          }
          if session.mode == .quad {
            TextField("Gracz 4", text: $session.player4Name)
              .textFieldStyle(.roundedBorder)
          }
        }
      }

      ArcadeUI.secondaryButton(
        "ZMIEŃ TRYB · \(nextModeLabel)",
        tint: NeonTheme.neonMagenta
      ) {
        session.cycleMode()
      }
    }
  }
}
