import Foundation

/// Czysty adapter SDK (bez BLE) — `update` + `input` w jednym miejscu.
@MainActor
public final class InputAdapter {
  private let sdk = MotionSDK()

  public var input: GameInput { sdk.input }
  public var config: MotionConfig {
    get { sdk.config }
    set { sdk.config = newValue }
  }

  public init() {}

  public func setMode(_ mode: MotionMode) {
    sdk.setMode(mode)
  }

  public func connect() { sdk.connect() }
  public func disconnect() { sdk.disconnect() }
  public var isConnected: Bool { sdk.isConnected }
  public var isReceiving: Bool { sdk.isReceiving }

  @discardableResult
  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    sdk.pollInput(deltaTime: deltaTime)
  }

  public func update(
    rawX: Double? = nil,
    bytes: [UInt8] = [],
    deltaTime: TimeInterval? = nil
  ) {
    _ = sdk.update(rawX: rawX, bytes: bytes, deltaTime: deltaTime)
  }

  public func reset() {
    sdk.reset()
  }
}
