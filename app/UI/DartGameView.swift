import SwiftUI
import VeltoKit

/// Opisuje struct `DartGameView` używany przez warstwę UI i logikę gry.
struct DartGameView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay

  @AppStorage(ArcadeTVSettings.dartBoardOnTVKey) private var dartBoardOnTV = false

  private var boardOnExternalDisplay: Bool {
    ArcadeTVSettings.dartUsesExternalBoard(
      dartBoardOnTV: dartBoardOnTV,
      externalConnected: quizDisplay.isExternalScreenConnected
    )
  }

  @ObservedObject var session: DartSession
  @ObservedObject var inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning
  @StateObject private var engine: GameEngine
  @State private var linkActive = false
  @State private var uiTick = 0

  /// Inicjalizuje instancję i ustawia wymagane zależności.
  init(session: DartSession, inputProvider: MotionInputProvider, tuning: GameTuning) {
    self.session = session
    self.inputProvider = inputProvider
    self.tuning = tuning
    _engine = StateObject(
      wrappedValue: GameEngine(
        game: DartGame(
          playerCount: session.playerCount,
          playerNames: (0 ..< session.playerCount).map { session.name(at: $0) },
          grip: DartGripMapping.from(axisMapping: inputProvider.config.axisMapping),
          restoredMatch: session.savedMatch
        ),
        inputProvider: inputProvider
      )
    )
  }

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    GeometryReader { geo in
      let insets = geo.safeAreaInsets
      ZStack {
        Color.black.ignoresSafeArea()

        gameCanvas(in: geo.size)
          .padding(.top, insets.top + 44)
          .padding(.bottom, insets.bottom + 52)

        VStack(spacing: 0) {
          topBar(safeTop: insets.top)
          Spacer(minLength: 0)
          bottomBar(safeBottom: insets.bottom)
        }

        if let countdown = engine.dartHUD?.startCountdown {
          DartStartCountdownOverlay(value: countdown)
            .zIndex(30)
        }

        if let announcement = engine.dartHUD?.turnAnnouncement {
          if engine.dartHUD?.awaitingTurnStart == true {
            TrikiTurnConfirmBanner(playerName: announcement)
              .transition(.scale.combined(with: .opacity))
              .zIndex(25)
          } else {
            DartTurnChangeBanner(
              playerName: announcement,
              dartsLeft: engine.dartHUD?.dartsLeftInTurn ?? 3
            )
            .transition(.scale.combined(with: .opacity))
            .zIndex(20)
          }
        }
      }
      .animation(.spring(response: 0.45, dampingFraction: 0.72), value: engine.dartHUD?.turnAnnouncement)
      .animation(.easeOut(duration: 0.15), value: engine.dartHUD?.startCountdown)
    }
    .phonePortraitGame()
    .arcadePlaySession(active: true, music: .dartGame)
    .onAppear {
      trikiUI.isSuspended = true
      trikiUI.clear()
      if !inputProvider.isConnected {
        inputProvider.connect()
      }
      GameManager.applyMotionMode(gameType: .dart, to: inputProvider)
      inputProvider.motionSDK.engine.resetGestureBaseline()
      inputProvider.calibrateCenter()
      _ = inputProvider.pollInput()
      engine.dartGame?.applyGrip(from: inputProvider.config.axisMapping)
      if dartBoardOnTV {
        quizDisplay.setDartActive(true)
        syncTV()
      }
    }
    .onDisappear {
      if let dart = engine.dartGame {
        session.persistMatch(dart.snapshot())
      }
      trikiUI.isSuspended = false
      quizDisplay.setDartActive(false)
    }
    .onChange(of: engine.drawCommands) { _, _ in
      if dartBoardOnTV { syncTV() }
    }
    .onChange(of: engine.dartHUD) { _, _ in
      if dartBoardOnTV { syncTV() }
    }
    .onChange(of: dartBoardOnTV) { _, enabled in
      if enabled {
        quizDisplay.setDartActive(true)
        syncTV()
      } else {
        quizDisplay.setDartActive(false)
      }
    }
    .gameLoop { now in
      engine.step(now: now)
      uiTick &+= 1
      if uiTick % 6 == 0 {
        linkActive = inputProvider.isTrikiControlAvailable
        _ = inputProvider.pollInput()
        engine.dartGame?.applyGrip(from: inputProvider.config.axisMapping)
      }
      if dartBoardOnTV {
        syncTV()
      }
    }
  }

  @ViewBuilder
  private func gameCanvas(in size: CGSize) -> some View {
    let layout = PixelGridFitLayout.fit(
      gridWidth: GameContext.width,
      gridHeight: GameContext.height,
      in: size
    )
    ZStack {
      if boardOnExternalDisplay {
        phonePilotCanvas(in: size)
      } else {
        PixelCanvas(
          commands: engine.drawCommands,
          gridWidth: GameContext.width,
          gridHeight: GameContext.height,
          displayMode: .fit
        )
        .frame(width: size.width, height: size.height)
      }

      if let hud = engine.dartHUD, !boardOnExternalDisplay {
        DartBoardMarkersOverlay(
          markers: hud.boardMarkers,
          layout: layout,
          markerSize: max(10, layout.scale * 2)
        )

        if hud.flightActive {
          DartFlyingDartView(
            progress: hud.flightProgress,
            diameter: max(22, layout.scale * 3.2)
          )
          .position(layout.point(gridX: hud.flightGridX, gridY: hud.flightGridY))
        } else {
          DartAimCircle(
            primed: hud.throwPrimed,
            feedbackLabel: hud.feedbackLabel
          )
          .position(layout.point(gridX: hud.aimGridX, gridY: hud.aimGridY))
        }

        if let feedback = hud.feedbackLabel, !hud.flightActive {
          DartShotFeedbackCard(
            pointsLine: feedback,
            detailLine: hud.lastHitLabel,
            isMiss: feedback == "MISS",
            scale: 0.85
          )
          .position(x: size.width / 2, y: size.height * 0.52)
          .transition(.scale.combined(with: .opacity))
        }
      }
    }
    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: engine.dartHUD?.feedbackLabel)
    .animation(.linear(duration: 0.05), value: engine.dartHUD?.flightProgress)
  }

  @ViewBuilder
  private func phonePilotCanvas(in size: CGSize) -> some View {
    ZStack {
      Color.black
      VStack(spacing: 16) {
        Image(systemName: "tv.fill")
          .font(.system(size: 36, weight: .semibold))
          .foregroundStyle(NeonTheme.neonYellow.opacity(0.85))
        Text("TARCZA NA TELEWIZORZE")
          .font(.system(size: 12, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonYellow)
        Text("Poniżej celownik — sterujesz Triki w dłoni")
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.55))
      }
      .padding(.top, size.height * 0.12)

      if let hud = engine.dartHUD {
        trikiPilotPanel(hud: hud)
          .padding(.horizontal, 12)
          .frame(maxHeight: .infinity, alignment: .bottom)
          .padding(.bottom, 8)
      }
    }
    .frame(width: size.width, height: size.height)
  }

  private func trikiPilotPanel(hud: DartGame.HUD) -> some View {
    VStack(spacing: 10) {
      if boardOnExternalDisplay {
        Group {
          if hud.isMultiplayer {
            DartRosterScoreStrip(hud: hud)
          } else {
            DartSoloScoreBadge(score: hud.player1Score)
          }
        }
        .frame(maxWidth: .infinity)
      }

      DartPhonePilotPanel(
        isConnected: inputProvider.isConnected,
        isReceiving: inputProvider.isReceiving,
        linkIndicatorColor: inputProvider.linkIndicatorColor,
        motionEnergy: inputProvider.liveInput.sensors.motion,
        throwState: hud.throwState,
        playZoneBand: hud.playZoneBand,
        boardOnTV: dartBoardOnTV
      )
    }
  }

  private func topBar(safeTop: CGFloat) -> some View {
    let hud = engine.dartHUD
    return HStack(spacing: 8) {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background(Color.white.opacity(0.12))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 2) {
        Text("DART")
          .font(.system(size: 10, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonCyan)
        if let hud, hud.isMultiplayer {
          Text("TURA · \(hud.activePlayerName)")
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonMagenta)
        }
        if inputProvider.isTrikiControlAvailable {
          Text("TRIKI · PILOT")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonGreen)
        }
        if !boardOnExternalDisplay {
          DartPlayZoneBadge(
            band: hud?.playZoneBand ?? .unknown,
            level: hud?.playZoneLevel ?? 0
          )
        }
        if let label = hud?.lastHitLabel, !label.isEmpty {
          Text(label)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(NeonTheme.neonMagenta)
        }
      }

      Spacer()

      if let hud {
        if hud.isMultiplayer {
          DartRosterScoreStrip(hud: hud)
        } else {
          DartSoloScoreBadge(score: hud.player1Score)
        }
      }

      if dartBoardOnTV || quizDisplay.isExternalScreenConnected {
        if quizDisplay.isExternalScreenConnected {
          Image(systemName: "tv.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(NeonTheme.neonYellow)
        }
        AirPlayRoutePicker(scale: 1.8)
          .airPlayHitTarget(size: 36)
      }

      Circle()
        .fill(inputProvider.linkIndicatorColor)
        .frame(width: 7, height: 7)
    }
    .padding(.horizontal, 12)
    .padding(.top, safeTop + 4)
    .padding(.bottom, 6)
  }

  private func bottomBar(safeBottom: CGFloat) -> some View {
    let hasFeedback = engine.dartHUD?.feedbackLabel != nil
    return VStack(spacing: 4) {
      if !hasFeedback, let hud = engine.dartHUD, hud.playZoneBand != .unknown {
        Text(hud.playZoneHint)
          .font(.system(size: 10, weight: .semibold, design: .monospaced))
          .foregroundStyle(playZoneColor(hud.playZoneBand))
      }
      if !hasFeedback {
        if let hud = engine.dartHUD, hud.isMultiplayer, hud.feedbackLabel == nil {
          Text("Na zmianę · teraz: \(hud.activePlayerName)")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(NeonTheme.neonMagenta)
        }
        if inputProvider.isTrikiControlAvailable, let hud = engine.dartHUD {
          Text(hud.throwState.phoneLabel)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(hud.throwPrimed ? NeonTheme.neonYellow : NeonTheme.neonCyan)
          Text(boardOnExternalDisplay
            ? "Pilot na telefonie · tarcza na TV · odległość = pozycja przed TV"
            : "Triki na telefonie · odległość = jak stoisz przed ekranem")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.55))
        } else {
          Label("Podłącz Triki (Bluetooth)", systemImage: "antenna.radiowaves.left.and.right")
        }
      }
    }
    .font(.system(size: 11, weight: .semibold, design: .monospaced))
    .foregroundStyle(.white.opacity(hasFeedback ? 0 : 0.65))
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 12)
    .padding(.bottom, safeBottom + 8)
  }

  private func playZoneColor(_ band: DartPlayZone.Band) -> Color {
    switch band {
    case .good: return NeonTheme.neonGreen
    case .close, .far: return NeonTheme.neonOrange
    case .unknown: return .white.opacity(0.5)
    }
  }

  private func syncTV() {
    quizDisplay.updateDart(
      commands: engine.drawCommands,
      hud: engine.dartHUD
    )
  }
}
