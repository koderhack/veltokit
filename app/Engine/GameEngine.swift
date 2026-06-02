/// Silnik wykonawczy gry: wejscie, aktualizacja i render.

import Foundation
import Combine
import VeltoKit

@MainActor
/// Reprezentuje typ `GameEngine`.
final class GameEngine: ObservableObject {
  @Published private(set) var drawCommands: [DrawCommand] = []
  @Published private(set) var hudInput = GameInput()

  private let game: any Game
  private let inputProvider: any InputProvider
  private let context = GameContext()
  private let publishesPixelFrame: Bool

  private var lastTimestamp: TimeInterval?
  private var hudRefreshAccum: TimeInterval = 0
  private var started = false
  @Published private(set) var frameIndex: UInt = 0
  @Published private(set) var quizHUD: QuizGame.HUD?
  @Published private(set) var dartHUD: DartGame.HUD?
  @Published private(set) var bowlingHUD: BowlingGame.HUD?

  private var lastDrawCommands: [DrawCommand] = []
  private var lastQuizHUD: QuizGame.HUD?

  private static let maxStep: TimeInterval = 1.0 / 60.0
  private static let hudRefreshInterval: TimeInterval = 0.12

/// Inicjalizuje nowa instancje.
  init(game: any Game, inputProvider: any InputProvider) {
    self.game = game
    self.inputProvider = inputProvider
    self.publishesPixelFrame = !(game is QuizGame) && !(game is BowlingGame)
  }

/// Wykonuje operacje `quizConfirmAnswer`.
  func quizConfirmAnswer() {
    (game as? QuizGame)?.confirmAnswer()
  }

/// Przechowuje wartosc `quizGame`.
  var quizGame: QuizGame? { game as? QuizGame }
/// Przechowuje wartosc `dartGame`.
  var dartGame: DartGame? { game as? DartGame }
/// Przechowuje wartosc `bowlingGame`.
  var bowlingGame: BowlingGame? { game as? BowlingGame }

/// Wykonuje operacje `calibrateDartPlayZone`.
  func calibrateDartPlayZone(sensors: TrikiSensors) {
    dartGame?.calibratePlayZone(sensors: sensors)
  }

/// Wykonuje operacje `startIfNeeded`.
  func startIfNeeded() {
    guard !started else { return }
    started = true
    if let motion = inputProvider as? MotionInputProvider,
       motion.config.mode == .paddle {
      motion.motionSDK.engine.resetPaddleMotion()
    }
    game.start(context: context)
  }

/// Wykonuje operacje `step`.
  func step(now: TimeInterval) {
    startIfNeeded()
    let deltaTime: TimeInterval
    if let lastTimestamp {
      deltaTime = max(0, min(Self.maxStep, now - lastTimestamp))
    } else {
      deltaTime = Self.maxStep
    }
    lastTimestamp = now

    let input: GameInput
    if let motion = inputProvider as? MotionInputProvider {
      input = motion.pollInput(deltaTime: deltaTime)
    } else {
      input = inputProvider.pollInput()
    }
    game.update(input: input, deltaTime: deltaTime)

    if let quiz = game as? QuizGame {
      let hud = quiz.currentHUD
      quizHUD = hud
      lastQuizHUD = hud
      dartHUD = nil
    } else if let dart = game as? DartGame {
      dartHUD = dart.currentHUD
      bowlingHUD = nil
      if lastQuizHUD != nil {
        lastQuizHUD = nil
        quizHUD = nil
      }
    } else if let bowling = game as? BowlingGame {
      bowlingHUD = bowling.currentHUD
      if bowling.consumeMotionCalibrationRequest(),
         let motion = inputProvider as? MotionInputProvider {
        _ = motion.pollInput()
        motion.motionSDK.engine.calibrateCenter()
        motion.motionSDK.engine.resetGestureBaseline()
      }
      dartHUD = nil
      if lastQuizHUD != nil {
        lastQuizHUD = nil
        quizHUD = nil
      }
    } else {
      if lastQuizHUD != nil {
        lastQuizHUD = nil
        quizHUD = nil
      }
      dartHUD = nil
      bowlingHUD = nil
    }

    hudRefreshAccum += deltaTime
    if hudRefreshAccum >= Self.hudRefreshInterval {
      hudRefreshAccum = 0
      hudInput = input
    }

    guard shouldRenderPixelFrame else {
      frameIndex &+= 1
      return
    }

    context.clear()
    game.render(context: context)
    let snapshot = context.commandSnapshot
    if snapshot != lastDrawCommands {
      lastDrawCommands = snapshot
      drawCommands = snapshot
    }
    frameIndex &+= 1
  }

  /// Quiz bez feedbacku nie odświeża canvasu; Pong tylko gdy zmieni się scena.
  private var shouldRenderPixelFrame: Bool {
    guard publishesPixelFrame else {
      return (game as? QuizGame)?.showsPixelFlash == true
    }
    return true
  }
}
