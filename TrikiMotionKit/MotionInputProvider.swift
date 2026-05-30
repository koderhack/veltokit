import Foundation
import Combine

private let motionInputHudPublishInterval: TimeInterval = 0.12

@MainActor
public protocol InputProvider: AnyObject {
  func pollInput(deltaTime: TimeInterval?) -> GameInput
}

extension InputProvider {
  public func pollInput() -> GameInput {
    pollInput(deltaTime: nil)
  }
}

/// BLE tylko buforuje bajty; cała logika w pollInput @ 60 FPS (DisplayLink).
@MainActor
public final class MotionInputProvider: InputProvider, ObservableObject {
  public let motionSDK = MotionSDK()

  @Published public private(set) var liveInput = GameInput()
  @Published public private(set) var isReceiving = false
  @Published public private(set) var isConnected = false

  public var config: MotionConfig {
    get { motionSDK.config }
    set { motionSDK.config = newValue }
  }

  private let parser: MotionParser
  private let bleManager: BLEManager
  private var cancellables: Set<AnyCancellable> = []
  private var lastPacketAt: TimeInterval = 0
  private var lastHudPublishAt: TimeInterval = 0
  private var latestInput = GameInput()

  public init() {
    self.bleManager = BLEManager()
    self.parser = MotionParser()
    parser.retainRecentFrames = false

    bleManager.rxBytes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] bytes in
        guard let self, !bytes.isEmpty else { return }
        self.motionSDK.enqueueBLE(bytes)
        if self.config.mode != .paddle {
          self.parser.enqueue(data: bytes)
        }
        self.lastPacketAt = Date().timeIntervalSince1970
        if !self.isReceiving { self.isReceiving = true }
      }
      .store(in: &cancellables)

    bleManager.$status
      .map { $0 == .connected }
      .removeDuplicates()
      .sink { [weak self] connected in
        self?.isConnected = connected
      }
      .store(in: &cancellables)
  }

  public func connect() {
    bleManager.autoConnectWhenSingleLikelyMatch = true
    bleManager.startScan(clearList: true)
  }

  public func disconnect() {
    bleManager.disconnect()
    resetInputState()
  }

  public func setInputMode(_ mode: MotionMode) {
    motionSDK.setMode(mode)
  }

  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    let now = Date().timeIntervalSince1970
    if now - lastPacketAt > 0.35 {
      isReceiving = false
    }

    if config.mode == .paddle {
      let out = motionSDK.updateFrame(deltaTime: deltaTime)
      var input = GameInput()
      input.posX = out.x
      input.posY = out.y
      input.lateral = out.x
      input.lateralSmooth = out.x
      latestInput = input
      if now - lastHudPublishAt >= motionInputHudPublishInterval {
        lastHudPublishAt = now
        liveInput = input
      }
      return input
    }

    parser.flush()
    motionSDK.setIngressSupplement(
      rotation: parser.sensors.rotation,
      tiltX: parser.sensors.tiltX,
      gyroY: parser.sensors.gyroY
    )
    let out = motionSDK.updateFrame(deltaTime: deltaTime)
    let impulses = parser.consumeImpulses()
    latestInput = makeGameInput(output: out, impulses: impulses)

    if now - lastHudPublishAt >= motionInputHudPublishInterval {
      lastHudPublishAt = now
      liveInput = latestInput
    }
    return latestInput
  }

  public func snapshotInput() -> GameInput {
    latestInput
  }

  public func resetInputState() {
    parser.resetStream()
    motionSDK.reset()
    liveInput = GameInput()
    latestInput = GameInput()
    isReceiving = false
    lastHudPublishAt = 0
  }

  public func calibrateCenter() {
    _ = pollInput()
    motionSDK.engine.calibrateCenter()
    publishLiveInput()
  }

  public func resetOffset() {
    motionSDK.engine.resetCenter()
    publishLiveInput()
  }

  public func flipPaddleOffsetSign() {
    motionSDK.engine.flipPaddleOffsetSign()
    publishLiveInput()
  }

  public func zeroNeutralTilt() {
    calibrateCenter()
  }

  private func publishLiveInput() {
    let out = motionSDK.output
    latestInput = makeGameInput(output: out, impulses: (false, false))
    liveInput = latestInput
    lastHudPublishAt = Date().timeIntervalSince1970
  }

  private func makeGameInput(
    output: MotionOutput,
    impulses: (click: Bool, shake: Bool)
  ) -> GameInput {
    let dbg = motionSDK.debug
    var input = GameInput()
    input.moveX = dbg.rawX
    input.moveY = dbg.rawY
    input.posX = output.x
    input.posY = output.y
    input.deltaX = dbg.relX
    input.deltaY = dbg.relY
    input.tiltX = dbg.relX
    input.tiltY = dbg.relY
    input.rotation = output.x
    input.lateral = output.x
    input.lateralSmooth = output.x
    input.velocityY = dbg.relY
    input.intensity = output.velocityX
    input.shotTriggered = output.didShoot
    input.primaryAction = output.didShoot || impulses.click
    input.shake = impulses.shake
    input.sensors = parser.sensors
    input.pointerDirection = pointerDirection(posX: output.x, posY: output.y)
    return input
  }

  private func pointerDirection(posX: Double, posY: Double, threshold: Double = 0.08) -> PointerDirection {
    let absX = abs(posX)
    let absY = abs(posY)
    if absX < threshold, absY < threshold { return .center }
    if absX >= absY { return posX < 0 ? .left : .right }
    return posY < 0 ? .down : .up
  }
}
