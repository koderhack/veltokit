import SwiftUI
import VeltoKit

/// Opisuje struct `BowlingGameView` używany przez warstwę UI i logikę gry.
struct BowlingGameView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay

  @AppStorage(ArcadeTVSettings.bowlingOnTVKey) private var bowlingOnTV = false
  @AppStorage(ArcadeTVSettings.bowlingInvertLateralKey) private var invertLateral = false

  @ObservedObject var session: BowlingSession
  @ObservedObject var inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning
  @StateObject private var engine: GameEngine
  @State private var linkActive = false
  @State private var uiTick = 0
  @State private var sceneReady = false

  /// Inicjalizuje instancję i ustawia wymagane zależności.
  init(session: BowlingSession, inputProvider: MotionInputProvider, tuning: GameTuning) {
    self.session = session
    self.inputProvider = inputProvider
    self.tuning = tuning
    _engine = StateObject(
      wrappedValue: GameEngine(
        game: BowlingGame(playerNames: session.playerNames),
        inputProvider: inputProvider
      )
    )
  }

  private var laneOnExternalDisplay: Bool {
    ArcadeTVSettings.bowlingUsesExternalLane(
      bowlingOnTV: bowlingOnTV,
      externalConnected: quizDisplay.isExternalScreenConnected
    )
  }

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    GeometryReader { geo in
      let insets = geo.safeAreaInsets
      ZStack {
        Color.black.ignoresSafeArea()

        if sceneReady, let bowling = engine.bowlingGame {
          if laneOnExternalDisplay {
            phonePilotLayer(size: geo.size)
          } else {
            PixelatedBowlingSceneView(scene: bowling.scene)
              .ignoresSafeArea()
          }
        }

        VStack(spacing: 0) {
          topBar(safeTop: insets.top)

          if let hud = engine.bowlingHUD {
            Group {
              if laneOnExternalDisplay {
                BowlingPhonePilotHUD(hud: hud, session: session, onConfirmTurnStart: confirmTurnStart)
              } else {
                BowlingHUDOverlay(hud: hud, onConfirmTurnStart: confirmTurnStart)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            Spacer(minLength: 0)
          }
        }
      }
    }
    .phonePortraitGame()
    .arcadePlaySession(active: true, music: .bowlingGame)
    .onAppear {
      trikiUI.isSuspended = true
      trikiUI.clear()
      if !inputProvider.isConnected {
        inputProvider.connect()
      }
      GameManager.applyMotionMode(gameType: .bowling, to: inputProvider)
      inputProvider.motionSDK.engine.resetGestureBaseline()
      _ = inputProvider.pollInput()
      engine.startIfNeeded()
      engine.bowlingGame?.applyAxisMapping(from: inputProvider.config.axisMapping)
      engine.bowlingGame?.invertLateral = invertLateral
      sceneReady = true
      if bowlingOnTV || quizDisplay.isExternalScreenConnected {
        quizDisplay.setBowlingActive(true)
      }
      syncTV()
    }
    .onDisappear {
      trikiUI.isSuspended = false
      sceneReady = false
      quizDisplay.setBowlingActive(false)
    }
    .onChange(of: engine.bowlingHUD) { _, _ in
      if bowlingOnTV || quizDisplay.isExternalScreenConnected {
        syncTV()
      }
    }
    .onChange(of: bowlingOnTV) { _, enabled in
      if enabled {
        quizDisplay.setBowlingActive(true)
        syncTV()
      } else {
        quizDisplay.setBowlingActive(false)
      }
    }
    .onChange(of: invertLateral) { _, value in
      engine.bowlingGame?.invertLateral = value
    }
    .gameLoop { now in
      engine.step(now: now)
      uiTick &+= 1
      if uiTick % 6 == 0 {
        linkActive = inputProvider.isTrikiControlAvailable
      }
      if bowlingOnTV || quizDisplay.isExternalScreenConnected {
        syncTV()
      }
    }
    .background {
      if laneOnExternalDisplay, sceneReady, let scene = engine.bowlingGame?.scene {
        BowlingSceneView(scene: scene, role: .simulationDriver)
          .frame(width: 1, height: 1)
          .opacity(0.01)
          .allowsHitTesting(false)
      }
    }
  }

  @ViewBuilder
  private func phonePilotLayer(size: CGSize) -> some View {
    ZStack {
      Color.black
      VStack(spacing: 16) {
        Image(systemName: "tv.fill")
          .font(.system(size: 36, weight: .semibold))
          .foregroundStyle(Color.orange.opacity(0.9))
        Text("TOR NA TELEWIZORZE")
          .font(.system(size: 12, weight: .heavy, design: .monospaced))
          .foregroundStyle(Color.orange)
        Text("Triki w dłoni — pochyl lewo/prawo, cofnij → rzuć")
          .font(.system(size: 11, weight: .medium, design: .rounded))
          .foregroundStyle(.white.opacity(0.55))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }
      .padding(.top, size.height * 0.18)
    }
    .frame(width: size.width, height: size.height)
  }

  private func syncTV() {
    quizDisplay.updateBowling(
      hud: engine.bowlingHUD,
      scene: engine.bowlingGame?.scene
    )
  }

  private func confirmTurnStart() {
    engine.bowlingGame?.confirmTurnStartFromUI()
  }

  private func topBar(safeTop: CGFloat) -> some View {
    HStack(spacing: 8) {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: 34, height: 34)
          .background(Color.white.opacity(0.12))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 2) {
        Text("BOWLING 3D")
          .font(.system(size: 10, weight: .heavy, design: .monospaced))
          .foregroundStyle(NeonTheme.neonCyan)
        if let hud = engine.bowlingHUD {
          Text("\(session.partySummary) · frame \(hud.currentFrame)")
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonMagenta)
        }
        if laneOnExternalDisplay {
          Text("TV = tor · telefon = pilot Triki")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(Color.orange)
        } else if inputProvider.isTrikiControlAvailable {
          Text("TRIKI · COFNIJ → Rzuć!")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonGreen)
        }
      }

      Spacer()

      Button(action: { invertLateral.toggle() }) {
        HStack(spacing: 4) {
          Image(systemName: "arrow.left.arrow.right")
            .font(.system(size: 11, weight: .bold))
          Text(invertLateral ? "L↔P ON" : "L↔P")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
        }
        .foregroundStyle(invertLateral ? NeonTheme.neonYellow : .white.opacity(0.75))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(invertLateral ? Color.orange.opacity(0.35) : Color.white.opacity(0.1))
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(invertLateral ? Color.orange : Color.white.opacity(0.2), lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Odwróć lewo prawo")

      Circle()
        .fill(inputProvider.linkIndicatorColor)
        .frame(width: 7, height: 7)
    }
    .padding(.horizontal, 12)
    .padding(.top, safeTop + 4)
    .padding(.bottom, 6)
  }
}

/// Kompaktowy HUD na telefonie, gdy tor jest na TV.
struct BowlingPhonePilotHUD: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: BowlingGame.HUD
  /// Przechowuje wartość `session` wykorzystywaną przez dany komponent.
  let session: BowlingSession
  /// Przechowuje wartość `onConfirmTurnStart` wykorzystywaną przez dany komponent.
  var onConfirmTurnStart: () -> Void = {}

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        if !hud.showScoreboardInterstitial {
          BowlingCompactScoreStrip(hud: hud)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }

        Spacer()

        if hud.awaitingTurnStart, let announcement = hud.turnAnnouncement, !hud.showScoreboardInterstitial {
        VStack(spacing: 8) {
          Text("CELuj LEWO/PRAWO")
            .font(.system(size: 12, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonCyan)
          TrikiTurnConfirmBanner(playerName: announcement)
            .onTapGesture(perform: onConfirmTurnStart)
          Text("Przycisk Triki · start odliczania · albo dotknij baneru")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.5))
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
      } else {
        VStack(spacing: 6) {
          Text(hud.throwLabel.uppercased())
            .font(.system(size: 18, weight: .heavy, design: .monospaced))
            .foregroundStyle(hud.setupSecondsLeft > 0 ? Color.orange : (hud.throwPhase == .ready ? NeonTheme.neonYellow : NeonTheme.neonCyan))
          if hud.setupSecondsLeft > 0 {
            Text("Celuj lewo/prawo · rzut po odliczaniu")
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(.white.opacity(0.55))
          } else if hud.throwPhase == .pullingBack || hud.throwPhase == .ready {
            Text("Cofnij → mocno do przodu")
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .foregroundStyle(NeonTheme.neonYellow.opacity(0.85))
          }
          if !hud.lastThrowLabel.isEmpty {
            Text(hud.lastThrowLabel)
              .font(.system(size: 12, weight: .bold, design: .monospaced))
              .foregroundStyle(NeonTheme.neonGreen)
          }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(Color.black.opacity(0.55))
        .padding(.bottom, 16)
      }
      }

      if hud.showScoreboardInterstitial {
        BowlingFullscreenScoreboardOverlay(hud: hud, onConfirmTurnStart: onConfirmTurnStart)
      }
    }
    .animation(.easeInOut(duration: 0.28), value: hud.showScoreboardInterstitial)
  }
}
