import Foundation
import VeltoKit

/// Koordynator gry — logika, input, scena 3D.
final class BowlingGame: Game {
  /// Przechowuje wartość `name` wykorzystywaną przez dany komponent.
  let name = "Bowling"
  /// Przechowuje wartość `inputProfile` wykorzystywaną przez dany komponent.
  let inputProfile: GameInputProfile = .bowling

  /// Opisuje struct `HUD` używany przez warstwę UI i logikę gry.
  struct HUD: Equatable {
    var players: [BowlingGameLogic.Player]
    var currentPlayerIndex: Int
    var currentFrame: Int
    var throwPhase: BowlingInputHandler.ThrowPhase
    var throwLabel: String
    var lastThrowLabel: String
    var lastThrowPins: Int
    var gameOver: Bool
    var winnerName: String?
    var pinsStanding: Int
    var canThrow: Bool
    var setupSecondsLeft: Int
    var turnAnnouncement: String?
    var awaitingTurnStart: Bool
    /// Pełnoekranowa tabela — zmiana gracza, przerwa między graczami, koniec gry.
    var showScoreboardInterstitial: Bool
    var invertLateral: Bool
  }

  /// Opisuje enum `RoundPhase` używany przez warstwę UI i logikę gry.
  enum RoundPhase: Equatable {
    case aiming
    case rolling
    case showingResult
    case betweenPlayers
  }

  private var _scene: BowlingGameScene?
  /// Przechowuje wartość `scene` wykorzystywaną przez dany komponent.
  var scene: BowlingGameScene {
    if let existing = _scene { return existing }
    let created = BowlingGameScene()
    _scene = created
    return created
  }

  private(set) var logic: BowlingGameLogic
  private let inputHandler = BowlingInputHandler()

  private var roundPhase: RoundPhase = .aiming
  private var settleTimer: TimeInterval = 0
  private var resultTimer: TimeInterval = 0
  private var turnAnnouncement: String?
  private var turnAnnouncementTimer: TimeInterval = 0
  private var pinsAtThrowStart = 10
  private var standingPinCount = 10
  private var pendingPreviousPlayer = 0
  private var setupCountdown: TimeInterval = setupDuration
  private var awaitingTurnStart = false
  private var throwCalibrator = BowlingInvisibleCalibrator()
  private var calibrationAppliedThisSetup = false
  private var requestMotionCalibration = false
  private var scoreboardSplashRemaining: TimeInterval = 0
  private var turnStartConfirmGate = TrikiButtonConfirmGate()

  private static let setupDuration: TimeInterval = 3.5
  private static let scoreboardSplashDuration: TimeInterval = 2.8
  private static let scoreboardSplashGameOverDuration: TimeInterval = 5.0

  /// Przechowuje wartość `currentHUD` wykorzystywaną przez dany komponent.
  var currentHUD: HUD {
    HUD(
      players: logic.players,
      currentPlayerIndex: logic.currentPlayerIndex,
      currentFrame: logic.currentFrameNumber,
      throwPhase: inputHandler.phase,
      throwLabel: currentThrowLabel,
      lastThrowLabel: logic.lastThrowLabel,
      lastThrowPins: logic.lastThrowPins,
      gameOver: logic.gameOver,
      winnerName: logic.winnerName,
      pinsStanding: standingPinCount,
      canThrow: roundPhase == .aiming && !awaitingTurnStart && setupCountdown <= 0 && !logic.gameOver,
      setupSecondsLeft: awaitingTurnStart ? 0 : max(0, Int(setupCountdown.rounded(.up))),
      turnAnnouncement: turnAnnouncement,
      awaitingTurnStart: awaitingTurnStart,
      showScoreboardInterstitial: showScoreboardInterstitial,
      invertLateral: inputHandler.invertLateral
    )
  }

  private var showScoreboardInterstitial: Bool {
    logic.gameOver || roundPhase == .betweenPlayers || scoreboardSplashRemaining > 0
  }

  /// Przechowuje wartość `invertLateral` wykorzystywaną przez dany komponent.
  var invertLateral: Bool {
    get { inputHandler.invertLateral }
    set { inputHandler.invertLateral = newValue }
  }

  /// Wykonuje operację `applyAxisMapping` w bieżącym kontekście gry/UI.
  func applyAxisMapping(from axisMapping: MotionAxisMapping) {
    inputHandler.applyAxisMapping(axisMapping)
  }

  private var currentThrowLabel: String {
    if awaitingTurnStart {
      return "Celuj · przycisk = start"
    }
    if setupCountdown > 0 {
      let sec = max(1, Int(setupCountdown.rounded(.up)))
      return "Ustaw się · \(sec)"
    }
    return inputHandler.phase.label
  }

  /// Inicjalizuje instancję i ustawia wymagane zależności.
  init(playerNames: [String]) {
    logic = BowlingGameLogic(playerNames: playerNames)
  }

  /// Wykonuje operację `confirmTurnStartFromUI` w bieżącym kontekście gry/UI.
  func confirmTurnStartFromUI() {
    guard awaitingTurnStart, roundPhase == .aiming else { return }
    confirmTurnStart()
  }

  /// Po kalibracji — `GameEngine` zeruje offset w MotionEngine (niewidocznie dla gracza).
  func consumeMotionCalibrationRequest() -> Bool {
    guard requestMotionCalibration else { return false }
    requestMotionCalibration = false
    return true
  }

  /// Wykonuje operację `start` w bieżącym kontekście gry/UI.
  func start(context: GameContext) {
    _ = scene
    resetRound(fullPins: true)
    inputHandler.reset()
    turnStartConfirmGate.reset()
  }

  /// Wykonuje operację `update` w bieżącym kontekście gry/UI.
  func update(input: GameInput, deltaTime: TimeInterval) {
    scene.update(deltaTime: deltaTime)

    if turnAnnouncementTimer > 0 {
      turnAnnouncementTimer = max(0, turnAnnouncementTimer - deltaTime)
      if turnAnnouncementTimer == 0 { turnAnnouncement = nil }
    }

    if scoreboardSplashRemaining > 0 {
      scoreboardSplashRemaining = max(0, scoreboardSplashRemaining - deltaTime)
    }

    switch roundPhase {
    case .aiming:
      if awaitingTurnStart {
        // Fizyczny przycisk BLE (bytes[1]) — gest nie uruchamia tury.
        if turnStartConfirmGate.consume(input: input, deltaTime: deltaTime) {
          confirmTurnStart()
        }
        _ = inputHandler.update(input: input, deltaTime: deltaTime, aimEnabled: true, throwsEnabled: false)
        scene.setAiming(lateralPosX: inputHandler.aimPosX)
      } else {
        setupCountdown = max(0, setupCountdown - deltaTime)
        let readyToThrow = setupCountdown <= 0 && calibrationAppliedThisSetup
        let throwsEnabled = readyToThrow && !logic.gameOver

        let throwEvent = inputHandler.update(
          input: input,
          deltaTime: deltaTime,
          aimEnabled: true,
          throwsEnabled: throwsEnabled
        )
        scene.setAiming(lateralPosX: inputHandler.aimPosX)

        runInvisibleCalibration(input: input, deltaTime: deltaTime)
        if setupCountdown <= 0, !calibrationAppliedThisSetup {
          applyInvisibleCalibration(throwCalibrator.finalize(force: true))
        }

        if let throwEvent {
          beginThrow(event: throwEvent)
        }
      }

    case .rolling:
      if scene.shouldEndThrow() {
        finishThrow()
      } else {
        settleTimer = 0
      }

    case .showingResult:
      resultTimer += deltaTime
      if resultTimer >= 2.0 {
        advanceAfterResult()
      }

    case .betweenPlayers:
      resultTimer += deltaTime
      if resultTimer >= 1.0 {
        resetRound(fullPins: logic.needsPinReset)
      }
    }
  }

  /// Wykonuje operację `render` w bieżącym kontekście gry/UI.
  func render(context: GameContext) {}

  // MARK: - Private

  private func beginThrow(event: BowlingInputHandler.ThrowEvent) {
    guard roundPhase == .aiming else { return }
    scene.ensureStandingPins(standingPinCount)
    pinsAtThrowStart = standingPinCount
    scene.throwBall(
      power: event.power,
      lateralPosX: event.lateralPosX,
      releaseSpin: event.releaseSpin,
      releaseTiltVelocity: event.releaseTiltVelocity
    )
    roundPhase = .rolling
    settleTimer = 0
  }

  private func finishThrow() {
    scene.processKnockedPinsDuringRoll()
    let knockedNow = scene.countScoredPins()
    let pinsDown: Int
    if logic.currentFrame.rolls.isEmpty {
      pinsDown = knockedNow
    } else {
      pinsDown = min(knockedNow, pinsAtThrowStart)
    }

    let previousPlayer = logic.currentPlayerIndex
    let wasGameOver = logic.gameOver
    logic.addThrow(pins: pinsDown)
    if logic.gameOver, !wasGameOver {
      ArcadeAudio.bowlingWin()
      beginScoreboardSplash(duration: 5.0)
    }
    pendingPreviousPlayer = previousPlayer
    standingPinCount = max(0, pinsAtThrowStart - pinsDown)

    if pinsDown > 0 {
      scene.removeKnockedPins()
      ArcadeAudio.bowlingPinsKnocked(count: pinsDown)
    } else {
      // Usuń ewentualne oznaczone kręgle (np. po animacji), żeby nie zostawały w tablicy.
      scene.removeKnockedPins()
    }

    // Kula zostaje na torze do końca ekranu wyniku — reset dopiero przed następnym rzutem.

    if logic.lastThrowPins == 10, logic.currentFrame.rolls.count == 1, logic.currentFrameIndex < 9 {
      ArcadeAudio.bowlingStrike()
    } else if logic.currentFrame.isSpare {
      ArcadeAudio.bowlingSpare()
    } else {
      ArcadeAudio.bowlingCrowdCheer(pinsDown: pinsDown)
    }

    roundPhase = .showingResult
    resultTimer = 0
    settleTimer = 0
  }

  private func advanceAfterResult() {
    guard !logic.gameOver else {
      scene.resetBall()
      roundPhase = .aiming
      return
    }

    let previousPlayer = pendingPreviousPlayer
    let needsFull = logic.needsPinReset
    let needsPartial = logic.needsPartialPinReset

    if needsFull {
      announceTurnIfNeeded(previousPlayer: previousPlayer)
      beginScoreboardSplash()
      roundPhase = .betweenPlayers
      resultTimer = 0
      standingPinCount = 10
    } else if needsPartial {
      scene.prepareSecondThrow()
      standingPinCount = max(0, 10 - logic.currentFrame.rolls[0])
      scene.ensureStandingPins(standingPinCount)
      enterAimingPhase()
    } else {
      scene.ensureStandingPins(standingPinCount)
      resetRound(fullPins: false)
    }
  }

  private func announceTurnIfNeeded(previousPlayer: Int) {
    let name = logic.currentPlayer.name
    let playerChanged = logic.currentPlayerIndex != previousPlayer
    if playerChanged || logic.currentFrame.rolls.isEmpty {
      turnAnnouncement = name
      if playerChanged {
        beginScoreboardSplash()
      }
      ArcadeAudio.turnChange()
    }
  }

  private func beginScoreboardSplash(duration: TimeInterval = 2.8) {
    scoreboardSplashRemaining = max(scoreboardSplashRemaining, duration)
  }

  private func confirmTurnStart() {
    scoreboardSplashRemaining = 0
    awaitingTurnStart = false
    setupCountdown = Self.setupDuration
    calibrationAppliedThisSetup = false
    throwCalibrator.reset()
    turnAnnouncement = nil
    turnAnnouncementTimer = 0
    inputHandler.prepareForTurnGate()
    requestMotionCalibration = false
    QuizSFX.menuConfirm()
  }

  private func runInvisibleCalibration(input: GameInput, deltaTime: TimeInterval) {
    guard !calibrationAppliedThisSetup else { return }
    if throwCalibrator.feed(input: input, deltaTime: deltaTime) {
      applyInvisibleCalibration(throwCalibrator.finalize())
    }
  }

  private func applyInvisibleCalibration(_ result: BowlingInvisibleCalibrator.Result) {
    guard !calibrationAppliedThisSetup else { return }
    calibrationAppliedThisSetup = true
    inputHandler.applyInvisibleCalibration(result, currentAim: inputHandler.aimPosX)
    requestMotionCalibration = true
  }

  private func resetRound(fullPins: Bool) {
    if fullPins {
      scene.resetAllPins()
      standingPinCount = 10
    } else {
      scene.resetBall()
    }
    scene.resetBall()
    enterAimingPhase()
  }

  private func enterAimingPhase() {
    roundPhase = .aiming
    scene.ensureStandingPins(standingPinCount)
    inputHandler.prepareForTurnGate()
    turnStartConfirmGate.reset()
    awaitingTurnStart = true
    setupCountdown = 0
    turnAnnouncement = logic.currentPlayer.name
  }
}
