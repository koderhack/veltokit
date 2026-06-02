import Foundation

/// Kompatybilność — deleguje do `MotionConfig`.
public struct PointerConfig: Equatable {
  /// Tryb sterowania przekazywany do `motion`.
  public var mode: MotionMode {
    get { motion.mode }
    set { motion.mode = newValue }
  }

  /// Docelowa konfiguracja silnika ruchu.
  public var motion: MotionConfig

  /// Tworzy konfigurację zgodności dla starszego API wskaźnika.
  public init(motion: MotionConfig = MotionConfig()) {
    self.motion = motion
  }

  /// Domyślna konfiguracja zgodności.
  public static let `default` = PointerConfig()
  /// Preset zgodności dla trybu paletki.
  public static let paddleDefaults = PointerConfig(motion: {
    var c = MotionConfig()
    c.mode = .paddle
    return c
  }())
  /// Preset zgodności dla trybu wskaźnika.
  public static let pointerDefaults = PointerConfig(motion: {
    var c = MotionConfig()
    c.mode = .pointer
    return c
  }())
}

/// Kierunek wskaźnika wyliczony z osi X/Y.
public enum PointerDirection: String, Sendable {
  case left = "LEFT"
  case right = "RIGHT"
  case up = "UP"
  case down = "DOWN"
  case center = "CENTER"
}
