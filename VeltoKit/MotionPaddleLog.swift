import Foundation
import os

/// Logi paletki — domyślnie wyłączone (włącz `isEnabled` w DEBUG).
public enum MotionPaddleLog {
  private static let logger = Logger(subsystem: "com.koderteam.gametriki", category: "Paddle")

  /// Wyłączone = zero kosztu w pętli 60 FPS.
  public static var isEnabled = false

  private static var lastDirection = ""
  private static var lastLogTime: TimeInterval = 0
  private static let minInterval: TimeInterval = 0.5

  public struct Sample: Sendable {
    public var rotation: Double
    public var gyroZ: Double
    public var rawX: Double
    public var smoothX: Double
    public var relX: Double
    public var biasX: Double
    public var steer: Double
    public var posX: Double
    public var direction: String

    public init(
      rotation: Double = 0,
      gyroZ: Double = 0,
      rawX: Double = 0,
      smoothX: Double = 0,
      relX: Double = 0,
      biasX: Double = 0,
      steer: Double = 0,
      posX: Double = 0,
      direction: String = "ŚRODEK"
    ) {
      self.rotation = rotation
      self.gyroZ = gyroZ
      self.rawX = rawX
      self.smoothX = smoothX
      self.relX = relX
      self.biasX = biasX
      self.steer = steer
      self.posX = posX
      self.direction = direction
    }
  }

  public static func directionLabel(for value: Double, threshold: Double = 0.03) -> String {
    if value < -threshold { return "LEWO ←" }
    if value > threshold { return "PRAWO →" }
    return "ŚRODEK"
  }

  public static func emit(_ sample: Sample, force: Bool = false) {
    #if DEBUG
    guard isEnabled else { return }
    #else
    return
    #endif

    let now = Date().timeIntervalSince1970
    let dir = sample.direction
    let moving = abs(sample.steer) > 0.04 || abs(sample.relX) > 0.04
    let dirChanged = dir != lastDirection
    let due = now - lastLogTime >= minInterval

    guard force || dirChanged || (moving && due) else { return }

    lastDirection = dir
    lastLogTime = now

    let line = """
    [\(dir)] rot=\(fmt(sample.rotation)) gz=\(fmt(sample.gyroZ)) rawX=\(fmt(sample.rawX)) \
    smooth=\(fmt(sample.smoothX)) rel=\(fmt(sample.relX)) bias=\(fmt(sample.biasX)) \
    steer=\(fmt(sample.steer)) posX=\(fmt(sample.posX))
    """
    logger.info("\(line, privacy: .public)")
  }

  public static func reset() {
    lastDirection = ""
    lastLogTime = 0
  }

  private static func fmt(_ v: Double) -> String {
    String(format: "%+.3f", v)
  }
}
