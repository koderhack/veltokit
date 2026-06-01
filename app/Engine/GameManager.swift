import Foundation
import VeltoKit

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
    let mode = motionMode(for: gameType)
    applyMode(mode, to: motion)
    if gameType == .dart {
      motion.config.referenceDriftEnabled = true
      motion.config.inputSmoothing = 0.22
      motion.config.pointerSensitivity = 0.14
      motion.config.pointerRotDamping = 0.985
      motion.config.pointerOutputSmoothing = 0.28
      motion.config.deadzone = 0.01
      motion.motionSDK.engine.resetGestureBaseline()
    }
    if gameType == .bowling {
      motion.config.referenceDriftEnabled = false
      motion.config.inputSmoothing = 0.22
      motion.config.pointerSensitivity = 0.10
      motion.config.pointerRotDamping = 0.985
      motion.config.pointerOutputSmoothing = 0.30
      motion.config.deadzone = 0.012
      motion.motionSDK.engine.resetGestureBaseline()
    }
    restoreDartLobbyAxisMapping(to: motion)
  }

  /// Menu / quiz / kalibracja — poziomy wybór + hold (jak w quizie).
  static func applyUIMode(to motion: MotionInputProvider) {
    applyMode(.paddle, to: motion)
    restoreDartLobbyAxisMapping(to: motion)
  }

  /// Odwrócenia osi z lobby — nie resetować przy przełączaniu trybu SDK.
  static func restoreDartLobbyAxisMapping(to motion: MotionInputProvider) {
    var axes = motion.config.axisMapping
    DartLobbySettings.applyToAxisMapping(&axes)
    motion.config.axisMapping = axes
  }
}
