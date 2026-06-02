import SwiftUI
import VeltoKit

/// Dart calibration flow screen with Triki-driven confirmation and TV synchronization.
///
/// This file hosts the dedicated pre-game calibration wizard used to capture per-player
/// throw posture and publish mirrored UI state to external display.

/// Kreator kalibracji Triki — instrukcje i menu na TV, Triki = wybór + przycisk.
struct DartCalibrationFlowView: View {
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @Environment(\.dismiss) private var dismiss

  @ObservedObject var session: DartSession
  @ObservedObject var inputProvider: MotionInputProvider
  @AppStorage(ArcadeTVSettings.dartBoardOnTVKey) private var dartBoardOnTV = false
  @AppStorage(ArcadeSettings.keepScreenOnDuringPlayKey) private var keepScreenOnDuringPlay = true

  /// Przechowuje wartość `onFinished` wykorzystywaną przez dany komponent.
  let onFinished: () -> Void

  @StateObject private var wizard: DartCalibrationWizard

  /// Number of Triki menu slots currently visible in the calibration flow.
  private var trikiSlotCount: Int {
    wizard.isComplete ? 2 : 1
  }

  /// Whether phone HUD should be visible when navigation is delegated to TV.
  private var trikiPhoneHUD: Bool {
    !quizDisplay.isExternalScreenConnected
  }

  /// Inicjalizuje instancję i ustawia wymagane zależności.
  /// Creates calibration flow with injected session and motion provider.
  ///
  /// - Parameters:
  ///   - session: Active dart session used to persist calibration outcomes.
  ///   - inputProvider: Motion input adapter that provides live sensor stream.
  ///   - onFinished: Callback fired after user chooses to start the game.
  init(
    session: DartSession,
    inputProvider: MotionInputProvider,
    onFinished: @escaping () -> Void
  ) {
    self.session = session
    self.inputProvider = inputProvider
    self.onFinished = onFinished
    _wizard = StateObject(wrappedValue: DartCalibrationWizard(session: session))
  }

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  /// Renders calibration instructions, Triki controls, and TV mirroring hooks.
  var body: some View {
    ZStack {
      ArcadeUI.screenBackground
      VStack(spacing: 16) {
        DartPhoneTVCompanion(
          inputProvider: inputProvider,
          tvConnected: quizDisplay.isExternalScreenConnected,
          title: quizDisplay.isExternalScreenConnected ? "KALIBRACJA NA TV" : "KALIBRACJA TRIKI",
          subtitle: quizDisplay.isExternalScreenConnected
            ? (wizard.isComplete
              ? "Na TV wybierz A lub B (Triki) · telefon bez paska sterowania"
              : "Patrz na TV · potwierdzaj krok Triki na ekranie telewizora")
            : (wizard.isComplete
              ? "Wybierz start lub anuluj Triki / przyciskiem"
              : "Wykonuj kroki na telefonie · hold Triki = potwierdź")
        )
        if !wizard.isComplete {
          Text(wizard.step.phoneHint)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(NeonTheme.neonCyan.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        Spacer(minLength: 0)
      }
      .padding(16)
    }
    .navigationBarBackButtonHidden(true)
    .arcadePlaySession(active: keepScreenOnDuringPlay, music: .dartLobby)
    .trikiUIScreen(itemCount: trikiSlotCount, isActive: true, showsPhoneHUD: trikiPhoneHUD, onActivate: handleTrikiActivate)
    .onAppear {
      if !inputProvider.isConnected { inputProvider.connect() }
      GameManager.applyUIMode(to: inputProvider)
      wizard.resetForPlayer(0)
      wizard.applyGrip(from: inputProvider.config.axisMapping)
      activateCalibrationTV()
      syncTV()
    }
    .onDisappear {
      quizDisplay.setDartCalibrationActive(false)
    }
    .onChange(of: trikiUI.focusIndex) { _, _ in syncTV() }
    .onChange(of: trikiUI.holdProgress) { _, _ in syncTV() }
    .onChange(of: quizDisplay.isExternalScreenConnected) { _, connected in
      if connected { trikiUI.clearFocus() }
      syncTV()
    }
    .background {
      TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
        Color.clear
          .onChange(of: timeline.date.timeIntervalSinceReferenceDate, initial: true) { _, _ in
            _ = inputProvider.pollInput()
            wizard.applyGrip(from: inputProvider.config.axisMapping)
            wizard.tick(
              sensors: inputProvider.liveInput.sensors,
              deltaTime: 1.0 / 30.0
            )
            syncTV()
          }
      }
    }
  }

  /// Enables calibration payload on TV when TV output is expected.
  private func activateCalibrationTV() {
    if dartBoardOnTV || quizDisplay.isExternalScreenConnected {
      quizDisplay.setDartCalibrationActive(true)
    }
  }

  /// Handles Triki activation in wizard and completion menu states.
  ///
  /// - Parameter index: Selected menu slot index.
  /// - Side Effects: May dismiss the view or finish calibration flow.
  private func handleTrikiActivate(_ index: Int) {
    if wizard.isComplete {
      if index == 0 {
        quizDisplay.setDartCalibrationActive(false)
        onFinished()
      } else {
        quizDisplay.setDartCalibrationActive(false)
        dismiss()
      }
      return
    }
    wizard.confirmCurrentStep(sensors: inputProvider.liveInput.sensors)
  }

  /// Pushes latest wizard and focus state to external TV payload.
  private func syncTV() {
    guard quizDisplay.dartCalibrationPayload.isActive else { return }
    quizDisplay.updateDartCalibration(
      step: wizard.step,
      progress: wizard.progress,
      playerName: wizard.playerDisplayName(for: wizard.playerIndex),
      playerIndex: wizard.playerIndex,
      playerCount: wizard.playerCount,
      focusIndex: trikiUI.focusIndex,
      holdProgress: trikiUI.holdProgress,
      showPlayMenu: wizard.isComplete,
      menuChoices: calibrationMenuChoices()
    )
  }

  /// Returns menu choices for TV overlay depending on wizard completion.
  private func calibrationMenuChoices() -> [TVMenuChoice] {
    if wizard.isComplete {
      return [
        TVMenuChoice(slot: 0, letter: "A", text: "ROZPOCZNIJ GRĘ", menuItem: nil, navigation: nil),
        TVMenuChoice(slot: 1, letter: "B", text: "ANULUJ", menuItem: nil, navigation: nil),
      ]
    }
    return [
      TVMenuChoice(slot: 0, letter: "A", text: "POTWIERDŹ TEN KROK", menuItem: nil, navigation: nil),
    ]
  }
}
