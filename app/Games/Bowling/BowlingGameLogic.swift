import Foundation

/// Logika punktacji kręgli (10 frame'ów, strike/spare, multiplayer).
final class BowlingGameLogic {
  struct Frame: Equatable {
    var rolls: [Int] = []
    var score: Int?
    var isStrike: Bool { rolls.first == 10 }
    var isSpare: Bool {
      guard rolls.count >= 2 else { return false }
      return rolls[0] < 10 && rolls[0] + rolls[1] == 10
    }
  }

  struct Player: Equatable, Identifiable {
    var id: String { name }
    var name: String
    var frames: [Frame]

    init(name: String) {
      self.name = name
      self.frames = (0..<10).map { _ in Frame() }
    }

    var totalScore: Int {
      frames.compactMap(\.score).last ?? 0
    }

    /// Do UI — oficjalny wynik albo suma zatoczonych lotek, zanim frame się domknie.
    var displayTotal: Int {
      if let official = frames.compactMap(\.score).last { return official }
      return frames.flatMap(\.rolls).reduce(0, +)
    }
  }

  private(set) var players: [Player]
  private(set) var currentPlayerIndex = 0
  private(set) var currentFrameIndex = 0
  private(set) var gameOver = false
  private(set) var winnerName: String?
  private(set) var lastThrowPins = 0
  private(set) var lastThrowLabel = ""

  var currentPlayer: Player { players[currentPlayerIndex] }
  var currentFrame: Frame { players[currentPlayerIndex].frames[currentFrameIndex] }
  var currentFrameNumber: Int { currentFrameIndex + 1 }

  var rollsRemainingInFrame: Int {
    let frame = currentFrame
    if currentFrameIndex == 9 {
      if frame.rolls.isEmpty { return 2 }
      if frame.rolls[0] == 10 { return max(0, 3 - frame.rolls.count) }
      if frame.rolls.count == 1 { return 1 }
      if frame.rolls.count == 2, frame.rolls[0] + frame.rolls[1] == 10 { return 1 }
      return max(0, 2 - frame.rolls.count)
    }
    if frame.rolls.isEmpty { return 2 }
    if frame.rolls[0] == 10 { return 0 }
    return max(0, 2 - frame.rolls.count)
  }

  var needsPinReset: Bool {
    let frame = currentFrame
    guard !frame.rolls.isEmpty else { return true }
    if currentFrameIndex == 9 { return frame.rolls.count >= 3 || isFrameComplete(frameIndex: 9, rolls: frame.rolls) }
    if frame.rolls[0] == 10 { return true }
    return frame.rolls.count >= 2
  }

  var needsPartialPinReset: Bool {
    let frame = currentFrame
    guard currentFrameIndex < 9 else { return false }
    return frame.rolls.count == 1 && frame.rolls[0] < 10
  }

  init(playerNames: [String]) {
    let names = playerNames.isEmpty ? ["Gracz 1"] : playerNames
    players = names.map { Player(name: $0.isEmpty ? "Gracz" : $0) }
  }

  func addThrow(pins knocked: Int) {
    guard !gameOver else { return }

    let frameIdx = currentFrameIndex
    var frame = players[currentPlayerIndex].frames[frameIdx]
    let prior = frame.rolls

    let capped: Int
    if frameIdx < 9, prior.count == 1, prior[0] < 10 {
      capped = min(knocked, 10 - prior[0])
    } else {
      capped = min(knocked, 10)
    }

    frame.rolls.append(capped)
    players[currentPlayerIndex].frames[frameIdx] = frame
    lastThrowPins = capped
    lastThrowLabel = label(for: capped, frame: frame)

    calculateScore()
    advanceTurnIfNeeded()
  }

  func calculateScore() {
    for playerIndex in players.indices {
      let rolls = flattenedRolls(for: players[playerIndex])
      var rollIndex = 0
      var cumulative = 0

      for frameIndex in 0..<10 {
        guard rollIndex < rolls.count else { break }

        if frameIndex == 9 {
          let frameThrows = players[playerIndex].frames[9].rolls
          guard isFrameComplete(frameIndex: 9, rolls: frameThrows) else { continue }
          cumulative += frameThrows.reduce(0, +)
          players[playerIndex].frames[9].score = cumulative
          continue
        }

        if rolls[rollIndex] == 10 {
          guard rollIndex + 2 < rolls.count else { break }
          cumulative += 10 + rolls[rollIndex + 1] + rolls[rollIndex + 2]
          players[playerIndex].frames[frameIndex].score = cumulative
          rollIndex += 1
        } else if rollIndex + 1 < rolls.count {
          let sum = rolls[rollIndex] + rolls[rollIndex + 1]
          if sum == 10 {
            guard rollIndex + 2 < rolls.count else { break }
            cumulative += 10 + rolls[rollIndex + 2]
            players[playerIndex].frames[frameIndex].score = cumulative
            rollIndex += 2
          } else {
            cumulative += sum
            players[playerIndex].frames[frameIndex].score = cumulative
            rollIndex += 2
          }
        }
      }
    }
  }

  private func flattenedRolls(for player: Player) -> [Int] {
    player.frames.flatMap(\.rolls)
  }

  private func label(for pins: Int, frame: Frame) -> String {
    if pins == 10, frame.rolls.count == 1 { return "STRIKE!" }
    if frame.isSpare { return "SPARE!" }
    return "\(pins) kręgli"
  }

  private func advanceTurnIfNeeded() {
    let frame = players[currentPlayerIndex].frames[currentFrameIndex]
    guard isFrameComplete(frameIndex: currentFrameIndex, rolls: frame.rolls) else { return }

    if currentPlayerIndex + 1 < players.count {
      currentPlayerIndex += 1
    } else {
      currentPlayerIndex = 0
      currentFrameIndex += 1
      if currentFrameIndex >= 10 {
        finishGame()
      }
    }
  }

  private func isFrameComplete(frameIndex: Int, rolls frameThrows: [Int]) -> Bool {
    guard !frameThrows.isEmpty else { return false }
    if frameIndex < 9 {
      return frameThrows[0] == 10 || frameThrows.count >= 2
    }
    if frameThrows[0] == 10 {
      return frameThrows.count >= 3
    }
    if frameThrows.count >= 2, frameThrows[0] + frameThrows[1] == 10 {
      return frameThrows.count >= 3
    }
    return frameThrows.count >= 2
  }

  private func finishGame() {
    gameOver = true
    calculateScore()
    let best = players.max(by: { $0.totalScore < $1.totalScore })
    winnerName = best?.name
  }
}
