import Combine
import Foundation

private let motionHudPublishInterval: TimeInterval = 0.12

extension MotionSDK {
  /// Skan BLE + auto-connect do jedynego urządzenia z „triki” w nazwie.
  public func connect() {
    ensureBLEPipeline()
    bleManager?.autoConnectWhenSingleLikelyMatch = true
    bleManager?.startScan(clearList: true)
  }

  public func disconnect() {
    bleManager?.disconnect()
    resetConnectionState()
  }

  /// Wywołuj co klatkę gry (~60 Hz) po `connect()` — zwraca gotowy `GameInput`.
  @discardableResult
  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    guard let parser = streamParser else {
      updateFrame(deltaTime: deltaTime)
      return input
    }

    let now = Date().timeIntervalSince1970
    if now - lastPacketAt > 0.35, isReceiving { isReceiving = false }

    if config.mode == .paddle {
      parser.refreshTiltSensors()
      parser.flushImpulsesOnly()
      let impulses = parser.consumeImpulses()
      let out = updateFrame(deltaTime: deltaTime)
      var enriched = input
      enriched.tiltY = parser.sensors.tiltY
      enriched.tiltX = parser.sensors.tiltX
      enriched.lateral = out.x
      enriched.lateralSmooth = out.x
      enriched.shake = impulses.shake
      enriched.sensors = parser.sensors
      applyClickToSensors(&enriched)
      latestEnrichedInput = enriched
      publishLiveInputIfNeeded(now: now, input: enriched)
      return enriched
    }

    parser.flush()
    setIngressSupplement(
      rotation: parser.sensors.rotation,
      tiltX: parser.sensors.tiltX,
      gyroY: parser.sensors.gyroY
    )
    let out = updateFrame(deltaTime: deltaTime)
    let impulses = parser.consumeImpulses()
    latestEnrichedInput = makeEnrichedGameInput(
      output: out,
      sdkInput: input,
      parser: parser,
      impulses: impulses
    )
    publishLiveInputIfNeeded(now: now, input: latestEnrichedInput)
    return latestEnrichedInput
  }

  public func snapshotInput() -> GameInput { latestEnrichedInput }

  public func calibrateNeutralPose() {
    _ = pollInput()
    engine.calibrateCenter()
    engine.resetPaddleMotion()
    refreshLiveInputFromEngine()
  }

  public func resetPaddleCenter() {
    engine.resetCenter()
    refreshLiveInputFromEngine()
  }

  public func flipPaddleOffsetSign() {
    engine.flipPaddleOffsetSign()
    refreshLiveInputFromEngine()
  }

  // MARK: - DEV / BLE diagnostics

  public var debugBLEBytes: Bool {
    get { bleManager?.debugRXBytes ?? false }
    set { bleManager?.debugRXBytes = newValue }
  }

  public var logBLEPacketsInDevMode: Bool {
    get { bleManager?.logRXPacketsInDevMode ?? false }
    set { bleManager?.logRXPacketsInDevMode = newValue }
  }

  public var bleDevLog: [String] { bleManager?.devRawLog ?? [] }

  public var bleByteProbe: BLEByteProbe { bleManager?.byteProbe ?? BLEByteProbe() }

  public func resetBLEProbe() {
    bleManager?.byteProbe.reset()
    bleManager?.devRawLog.removeAll()
  }

  public func clearBLEDevLog() { bleManager?.devRawLog.removeAll() }

  // MARK: - Private

  func ensureBLEPipeline() {
    guard bleManager == nil else { return }

    let ble = BLEManager()
    let parser = MotionParser()
    parser.retainRecentFrames = false
    bleManager = ble
    streamParser = parser

    ble.rxBytes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] bytes in
        guard let self, !bytes.isEmpty else { return }
        self.enqueueBLE(bytes)
        self.streamParser?.enqueue(data: bytes)
        self.lastPacketAt = Date().timeIntervalSince1970
        if !self.isReceiving { self.isReceiving = true }
      }
      .store(in: &bleCancellables)

    ble.$status
      .map { $0 == .connected }
      .removeDuplicates()
      .sink { [weak self] connected in
        self?.isConnected = connected
        if !connected { self?.resetConnectionState() }
      }
      .store(in: &bleCancellables)
  }

  func resetConnectionState() {
    streamParser?.resetStream()
    reset()
    liveInput = GameInput()
    latestEnrichedInput = GameInput()
    isReceiving = false
    lastHudPublishAt = 0
  }

  func refreshLiveInputFromEngine() {
    let out = output
    latestEnrichedInput = makeEnrichedGameInput(
      output: out,
      sdkInput: input,
      parser: streamParser,
      impulses: (false, false)
    )
    liveInput = latestEnrichedInput
    lastHudPublishAt = Date().timeIntervalSince1970
  }

  func publishLiveInputIfNeeded(now: TimeInterval, input: GameInput) {
    guard now - lastHudPublishAt >= motionHudPublishInterval else { return }
    lastHudPublishAt = now
    liveInput = input
  }

  func makeEnrichedGameInput(
    output: MotionOutput,
    sdkInput: GameInput,
    parser: MotionParser?,
    impulses: (click: Bool, shake: Bool)
  ) -> GameInput {
    let dbg = debug
    var enriched = sdkInput
    enriched.moveX = dbg.rawX
    enriched.moveY = dbg.rawY
    enriched.posX = output.x
    enriched.posY = output.y
    enriched.deltaX = dbg.relX
    enriched.deltaY = dbg.relY
    if let parser {
      enriched.tiltX = parser.sensors.tiltX
      enriched.tiltY = parser.sensors.tiltY
      enriched.rotation = output.x
      enriched.lateral = output.x
      enriched.lateralSmooth = output.x
      enriched.velocityY = dbg.relY
      enriched.intensity = output.velocityX
      enriched.shake = impulses.shake
      enriched.sensors = parser.sensors
      enriched.pointerDirection = pointerDirection(posX: output.x, posY: output.y)
    }
    applyClickToSensors(&enriched)
    return enriched
  }

  func applyClickToSensors(_ input: inout GameInput) {
    guard input.primaryAction else { return }
    var sensors = input.sensors
    sensors.click = true
    input.sensors = sensors
  }

  func pointerDirection(
    posX: Double,
    posY: Double,
    threshold: Double = 0.08
  ) -> PointerDirection {
    let absX = abs(posX)
    let absY = abs(posY)
    if absX < threshold, absY < threshold { return .center }
    if absX >= absY { return posX < 0 ? .left : .right }
    return posY < 0 ? .down : .up
  }
}
