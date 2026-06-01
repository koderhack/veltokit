import Foundation
import Combine

/// Fasada Motion SDK: pozycja, gest rzutu, przycisk BLE → `GameInput`.
@MainActor
public final class MotionSDK: ObservableObject {
  let processor = MotionProcessor()
  let gesture = GestureDetector()
  let button = ButtonDetector()
  public let engine: MotionEngine

  /// Ostatni bajt przycisku BLE (DEV).
  public var lastButtonByte: UInt8 { button.lastSeenButtonByte }

  public private(set) var input = GameInput()

  // MARK: - BLE (connect + pollInput)

  @Published public internal(set) var isConnected = false
  @Published public internal(set) var isReceiving = false
  @Published public internal(set) var liveInput = GameInput()

  var bleManager: BLEManager?
  var streamParser: MotionParser?
  var bleCancellables = Set<AnyCancellable>()
  var lastPacketAt: TimeInterval = 0
  var lastHudPublishAt: TimeInterval = 0
  var latestEnrichedInput = GameInput()

  public var config: MotionConfig {
    get { engine.config }
    set { engine.config = newValue }
  }

  public var mode: MotionMode {
    get { engine.config.mode }
    set { engine.setMode(newValue) }
  }

  public var output: MotionOutput { engine.output }
  public var debug: MotionDebug { engine.debug }

  private var rxBuffer: [UInt8] = []
  private var lastPollTime: TimeInterval?
  private var ingressRotation = 0.0
  private var ingressTiltX = 0.0
  private var ingressGyroY = 0.0
  private var latestPaddleRaw: Double?

  public init() {
    engine = MotionEngine(processor: processor, gesture: gesture)
  }

  public func setMode(_ mode: MotionMode) {
    engine.setMode(mode)
  }

  public func setIngressSupplement(rotation: Double, tiltX: Double, gyroY: Double) {
    ingressRotation = rotation
    ingressTiltX = tiltX
    ingressGyroY = gyroY
  }

  /// BLE callback — buforuje bajty (przycisk) i rawX w trybie paletki.
  public func enqueueBLE(_ data: [UInt8]) {
    guard !data.isEmpty else { return }
    button.process(data)
    if engine.config.mode == .paddle {
      if let raw = BLEGyroParser.gyroRawFromPacket(data) {
        latestPaddleRaw = raw
      }
      return
    }
    rxBuffer.append(contentsOf: data)
    if rxBuffer.count > 512 {
      rxBuffer.removeSubrange(0..<(rxBuffer.count - 256))
    }
  }

  public func flushIngress() {
    if engine.config.mode == .paddle {
      if let raw = latestPaddleRaw {
        engine.setRawX(raw)
      }
      return
    }

    let cfg = engine.config
    var tiltBlock: BLEGyroParser.GyroTriple?
    var gyroBlock: BLEGyroParser.GyroTriple?
    var blockIndex = 0

    if !rxBuffer.isEmpty {
      let blocks = BLEGyroParser.drainGyroBlocks(from: &rxBuffer)
      if !blocks.isEmpty {
        if let first = blocks.first {
          tiltBlock = BLEGyroParser.scaledTiltBlock(first)
        }
        if blocks.count >= 2 {
          gyroBlock = blocks[blocks.count - 1]
          blockIndex = blocks.count - 1
        }
      }
    }

    let gx = gyroBlock?.x ?? tiltBlock?.x ?? ingressTiltX
    let gy = gyroBlock?.y ?? tiltBlock?.y ?? ingressGyroY
    let gz = gyroBlock?.z ?? tiltBlock?.z ?? 0
    let mapped = cfg.axisMapping.map(
      gx: gx,
      gy: gy,
      gz: gz,
      rotation: ingressRotation
    )
    engine.setPaddleSources(rotation: mapped.x, gyroZ: gz)
    engine.updateRaw(x: mapped.x, y: mapped.y, gyroBlockIndex: blockIndex)
  }

  public func ingestTrikiFrame(
    gyroX: Double,
    gyroY: Double,
    gyroZ: Double,
    rotation: Double
  ) {
    ingressRotation = rotation
    ingressGyroY = gyroY
    let mapping = engine.config.axisMapping
    let mapped = mapping.map(gx: gyroX, gy: gyroY, gz: gyroZ, rotation: rotation)
    engine.setPaddleSources(rotation: mapped.x, gyroZ: gyroZ)
    if engine.config.mode == .paddle {
      latestPaddleRaw = mapped.x * BLEGyroParser.gyroDivisor
    } else {
      engine.updateRaw(x: mapped.x, y: mapped.y, gyroBlockIndex: 1)
    }
  }

  /// Aktualizacja klatki: opcjonalnie surowy X i pakiet BLE (przycisk).
  @discardableResult
  public func update(
    rawX: Double? = nil,
    bytes: [UInt8] = [],
    deltaTime: TimeInterval? = nil
  ) -> MotionOutput {
    if let rawX {
      engine.setRawX(rawX)
    }
    if !bytes.isEmpty {
      button.process(bytes)
    }
    return updateFrame(deltaTime: deltaTime)
  }

  @discardableResult
  public func updateFrame(deltaTime: TimeInterval? = nil) -> MotionOutput {
    flushIngress()
    let now = Date().timeIntervalSince1970
    let dt: TimeInterval
    if let deltaTime {
      dt = deltaTime
    } else {
      dt = min(0.05, max(0, now - (lastPollTime ?? now)))
    }
    lastPollTime = now
    engine.updateFrame(deltaTime: dt)
    publishInput()
    return engine.output
  }

  public func reset() {
    rxBuffer.removeAll(keepingCapacity: false)
    lastPollTime = nil
    ingressRotation = 0
    ingressTiltX = 0
    ingressGyroY = 0
    latestPaddleRaw = nil
    button.reset()
    engine.resetState()
    input = GameInput()
  }

  private func publishInput() {
    let out = engine.output
    let click = button.consumeClick()
    let throwShot = out.didShoot
    input.posX = out.x
    input.posY = out.y
    input.shotTriggered = throwShot
    input.primaryAction = click || throwShot
    input.throwPower = throwShot ? engine.lastGestureThrowPower : 0
    input.gesturePrimed = engine.gesturePrimed
  }
}
