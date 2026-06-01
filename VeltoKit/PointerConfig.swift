import Foundation

/// Kompatybilność — deleguje do `MotionConfig`.
public struct PointerConfig: Equatable {
  public var mode: MotionMode {
    get { motion.mode }
    set { motion.mode = newValue }
  }

  public var motion: MotionConfig

  public init(motion: MotionConfig = MotionConfig()) {
    self.motion = motion
  }

  public static let `default` = PointerConfig()
  public static let paddleDefaults = PointerConfig(motion: {
    var c = MotionConfig()
    c.mode = .paddle
    return c
  }())
  public static let pointerDefaults = PointerConfig(motion: {
    var c = MotionConfig()
    c.mode = .pointer
    return c
  }())
}

public enum PointerDirection: String, Sendable {
  case left = "LEFT"
  case right = "RIGHT"
  case up = "UP"
  case down = "DOWN"
  case center = "CENTER"
}
