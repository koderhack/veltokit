import Foundation
import Combine
import TrikiMotionKit

@MainActor
final class GameEngine: ObservableObject {
  @Published private(set) var drawCommands: [DrawCommand] = []
  @Published private(set) var hudInput = GameInput()

  private let game: any Game
  private let inputProvider: any InputProvider
  private let context = GameContext()

  private var lastTimestamp: TimeInterval?
  private var hudRefreshAccum: TimeInterval = 0
  private var started = false
  private var stepInFlight = false
  @Published private(set) var frameIndex: UInt = 0

  private static let maxStep: TimeInterval = 1.0 / 60.0
  private static let hudRefreshInterval: TimeInterval = 0.12

  init(game: any Game, inputProvider: any InputProvider) {
    self.game = game
    self.inputProvider = inputProvider
  }

  func startIfNeeded() {
    guard !started else { return }
    started = true
    if let motion = inputProvider as? MotionInputProvider,
       motion.config.mode == .paddle {
      motion.motionSDK.engine.resetPaddleMotion()
    }
    game.start(context: context)
  }

  func step(now: TimeInterval) {
    guard !stepInFlight else { return }
    stepInFlight = true
    defer { stepInFlight = false }

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

    hudRefreshAccum += deltaTime
    if hudRefreshAccum >= Self.hudRefreshInterval {
      hudRefreshAccum = 0
      hudInput = input
    }

    context.clear()
    game.render(context: context)
    // Nowa instancja tablicy — in-place `context.commands` nie odświeżało Canvas.
    drawCommands = context.commandSnapshot
    frameIndex &+= 1
  }
}