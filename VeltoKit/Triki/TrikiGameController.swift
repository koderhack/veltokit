import Combine
import Foundation

/// Publiczna fasada gamepada Triki — BLE → monitor → parser → adaptacyjny motion.
@MainActor
public final class TrikiGameController: ObservableObject {
  public enum InputMode: Sendable, Equatable {
    case game
    case smooth
  }

  public let ble = TrikiBLEManager()

  public var inputMode: InputMode = .game {
    didSet { motion.inputMode = mapInputMode(inputMode) }
  }

  public var debugParserLogging: Bool {
    get { parser.debugLoggingEnabled }
    set { parser.debugLoggingEnabled = newValue }
  }

  public var debugBLEMonitorLogging: Bool {
    get { bleMonitor.debugLoggingEnabled }
    set { bleMonitor.debugLoggingEnabled = newValue }
  }

  /// Odstęp publikacji HUD w trybie low power (mniej odświeżeń UI).
  public var lowPowerHudPublishInterval: TimeInterval = 0.35

  @Published public private(set) var gameInput = TrikiGameInput()
  @Published public private(set) var bleMode: TrikiBLEMode = .unknown
  @Published public private(set) var isConnected = false
  @Published public private(set) var isReceiving = false
  /// Tekst podpowiedzi UX przy low power.
  @Published public private(set) var idleStatusMessage: String? = nil

  private var parser = TrikiParser()
  private var motion = TrikiMotionEngine()
  private let bleMonitor = TrikiBLEMonitor()
  private var cancellables = Set<AnyCancellable>()
  private var lastPacketAt: TimeInterval = 0
  private var lastPollTime: TimeInterval?
  private var lastHudPublishAt: TimeInterval = 0
  private var lastWakeUpAttemptAt: TimeInterval = 0

  private var moveHandlers: [(Float) -> Void] = []
  private var shakeHandlers: [() -> Void] = []
  private var actionHandlers: [() -> Void] = []
  private var modeChangedHandlers: [(TrikiBLEMode) -> Void] = []

  public init() {
    motion.inputMode = .game
    wireBLE()
  }

  // MARK: - Connection

  public func connect() {
    ble.autoConnectWhenSingleLikelyMatch = true
    if ble.cachedPeripheralUUID != nil, ble.status == .idle {
      ble.connectCachedPeripheralIfAvailable()
    } else {
      ble.startScan(clearList: true)
    }
  }

  public func disconnect() {
    ble.disconnect()
    resetSession()
  }

  public func ingest(_ bytes: [UInt8]) {
    guard !bytes.isEmpty else { return }
    let now = Date().timeIntervalSince1970
    if let transition = bleMonitor.recordPacket(at: now) {
      applyBLEModeTransition(transition)
    }
    parser.append(bytes)
    lastPacketAt = now
    if !isReceiving { isReceiving = true }
    updateIdleMessage()
  }

  @discardableResult
  public func tick(deltaTime: TimeInterval? = nil) -> TrikiGameInput {
    let now = Date().timeIntervalSince1970
    if now - lastPacketAt > 0.35, isReceiving { isReceiving = false }

    if let transition = bleMonitor.evaluateStale(now: now) {
      applyBLEModeTransition(transition)
    }
    attemptWakeUpIfStuck(now: now)

    let dt: TimeInterval
    if let deltaTime {
      dt = deltaTime
    } else {
      dt = min(0.05, max(0, now - (lastPollTime ?? now)))
    }
    lastPollTime = now

    let frames = parser.drainParsedFrames()
    if !frames.isEmpty {
      motion.ingest(parsed: frames, deltaTime: dt)
      publishGameInputIfNeeded(now: now)
      dispatchCallbacks()
    } else if bleMode == .lowPower, now - lastHudPublishAt >= lowPowerHudPublishInterval {
      gameInput = motion.output
      lastHudPublishAt = now
    }

    return gameInput
  }

  public func resetSession() {
    parser.reset()
    motion.reset()
    bleMonitor.reset()
    gameInput = TrikiGameInput()
    bleMode = .unknown
    idleStatusMessage = nil
    isReceiving = false
    lastPollTime = nil
    lastHudPublishAt = 0
    lastWakeUpAttemptAt = 0
  }

  // MARK: - Public API

  public func getBLEMode() -> TrikiBLEMode { bleMode }

  public func getDirection() -> Float { motion.getDirection() }
  public func getVelocity() -> Float { motion.getVelocity() }
  public func isShake() -> Bool { motion.isShake() }
  public func isMoving() -> Bool { motion.isMoving() }

  public func onMove(_ handler: @escaping (Float) -> Void) {
    moveHandlers.append(handler)
  }

  public func onShake(_ handler: @escaping () -> Void) {
    shakeHandlers.append(handler)
  }

  public func onAction(_ handler: @escaping () -> Void) {
    actionHandlers.append(handler)
  }

  public func onModeChanged(_ handler: @escaping (TrikiBLEMode) -> Void) {
    modeChangedHandlers.append(handler)
  }

  public func clearHandlers() {
    moveHandlers.removeAll()
    shakeHandlers.removeAll()
    actionHandlers.removeAll()
    modeChangedHandlers.removeAll()
  }

  // MARK: - Private

  private func wireBLE() {
    ble.rxBytes
      .receive(on: DispatchQueue.main)
      .sink { [weak self] bytes in
        self?.ingest(bytes)
      }
      .store(in: &cancellables)

    ble.$status
      .map { $0 == .connected }
      .removeDuplicates()
      .sink { [weak self] connected in
        guard let self else { return }
        self.isConnected = connected
        if !connected { self.resetSession() }
      }
      .store(in: &cancellables)
  }

  private func applyBLEModeTransition(_ transition: TrikiBLEModeTransition) {
    bleMode = transition.current
    motion.setBLEMode(transition.current)
    for handler in modeChangedHandlers {
      handler(transition.current)
    }
    updateIdleMessage()
  }

  private func updateIdleMessage() {
    switch bleMode {
    case .lowPower:
      idleStatusMessage = "Bezruch — czekam na ruch"
    case .fast, .normal:
      idleStatusMessage = nil
    case .unknown:
      idleStatusMessage = nil
    }
  }

  private func publishGameInputIfNeeded(now: TimeInterval) {
    let interval: TimeInterval = bleMode == .lowPower ? lowPowerHudPublishInterval : 0
    if interval > 0, now - lastHudPublishAt < interval, lastHudPublishAt > 0 {
      return
    }
    gameInput = motion.output
    lastHudPublishAt = now
  }

  /// Po długim low power bez pakietów — delikatne „obudzenie” streamu (INIT).
  private func attemptWakeUpIfStuck(now: TimeInterval) {
    guard bleMode == .lowPower, isConnected else { return }
    guard now - lastPacketAt > 4.0 else { return }
    guard now - lastWakeUpAttemptAt > 5.0 else { return }
    lastWakeUpAttemptAt = now
    ble.sendInitAndStartIfReady()
    if debugBLEMonitorLogging {
      print("[TrikiGameController] wake-up INIT (low power stall)")
    }
  }

  private func dispatchCallbacks() {
    if gameInput.isMoving {
      for handler in moveHandlers { handler(gameInput.direction) }
    }
    if gameInput.isShake {
      for handler in shakeHandlers { handler() }
    }
    if gameInput.isAction {
      for handler in actionHandlers { handler() }
    }
  }

  private func mapInputMode(_ mode: InputMode) -> TrikiInputMode {
    switch mode {
    case .game: return .game
    case .smooth: return .smooth
    }
  }
}
