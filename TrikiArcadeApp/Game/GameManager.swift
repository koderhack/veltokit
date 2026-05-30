import Foundation
import TrikiMotionKit

/// Przełączanie gier i trybów Motion SDK (presety — bez ręcznego tuningu).
enum GameManager {
  static func motionMode(for gameType: GameType) -> MotionMode {
    gameType.inputProfile.motionMode
  }

  static func applyMode(_ mode: MotionMode, to motion: MotionInputProvider) {
    let savedAxes = motion.config.axisMapping
    motion.setInputMode(mode)
    var cfg = MotionConfig.preset(for: mode)
    if mode != .paddle {
      cfg.axisMapping = savedAxes
    } else {
      cfg.axisMapping = MotionConfig.preset(for: .paddle).axisMapping
    }
    motion.config = cfg
  }

  static func applyMotionMode(gameType: GameType, to motion: MotionInputProvider) {
    applyMode(motionMode(for: gameType), to: motion)
  }
}
