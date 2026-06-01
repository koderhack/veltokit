import SwiftUI
import VeltoKit

/// Kreator kalibracji Triki — instrukcje i menu na TV, Triki = wybór + przycisk.
struct DartCalibrationFlowView: View {
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @Environment(\.dismiss) private var dismiss

  @ObservedObject var session: DartSession
  @ObservedObject var inputProvider: MotionInputProvider
  @AppStorage(ArcadeTVSettings.dartBoardOnTVKey) private var dartBoardOnTV = false
  @AppStorage(ArcadeSettings.keepScreenOnDuringPlayKey) private var keepScreenOnDuringPlay = true

  let onFinished: () -> Void

  @StateObject private var wizard: DartCalibrationWizard

  private var trikiSlotCount: Int {
    wizard.isComplete ? 2 : 1
  }

  private var trikiPhoneHUD: Bool {
    !quizDisplay.isExternalScreenConnected
  }

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

  private func activateCalibrationTV() {
    if dartBoardOnTV || quizDisplay.isExternalScreenConnected {
      quizDisplay.setDartCalibrationActive(true)
    }
  }

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
