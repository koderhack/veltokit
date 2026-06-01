import Combine
import Foundation
import VeltoKit

/// Aplikacja demo — kalibracja UI + alias na `MotionSDK` z BLE.
@MainActor
public final class TrikiInputAdapter: InputProvider, ObservableObject {
  public let motionSDK = MotionSDK()

  @Published public private(set) var autoCalibrationState: AutoCalibrationState = .idle
  @Published public private(set) var showsCalibrationPrompt = false

  public enum AutoCalibrationState: Equatable {
    case idle
    case awaitingUser
    case done
  }

  public var liveInput: GameInput { motionSDK.liveInput }

  public var isReceiving: Bool { motionSDK.isReceiving }
  public var isConnected: Bool { motionSDK.isConnected }
  public var isTrikiControlAvailable: Bool { isConnected && isReceiving }

  public var config: MotionConfig {
    get { motionSDK.config }
    set { motionSDK.config = newValue }
  }

  private var autoCalibDoneForConnection = false

  public init() {}

  public func connect() { motionSDK.connect() }

  public func disconnect() {
    motionSDK.disconnect()
    resetAutoCalibrationSession()
  }

  public func performCalibration() {
    motionSDK.calibrateNeutralPose()
    autoCalibDoneForConnection = true
    autoCalibrationState = .done
    showsCalibrationPrompt = false
  }

  public func performAutoCalibration() { performCalibration() }

  public func presentCalibrationPrompt() {
    guard isConnected else { return }
    showsCalibrationPrompt = true
    autoCalibrationState = isReceiving ? .awaitingUser : .idle
  }

  public func skipCalibrationPrompt() {
    showsCalibrationPrompt = false
    autoCalibDoneForConnection = true
    autoCalibrationState = .idle
  }

  public func setInputMode(_ mode: MotionMode) {
    motionSDK.setMode(mode)
  }

  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    let input = motionSDK.pollInput(deltaTime: deltaTime)
    if isReceiving, isConnected, !autoCalibDoneForConnection {
      presentCalibrationPromptIfNeeded()
    }
    return input
  }

  public func snapshotInput() -> GameInput { motionSDK.snapshotInput() }

  public func resetInputState() {
    motionSDK.disconnect()
    resetAutoCalibrationSession()
  }

  public func calibrateCenter() { motionSDK.calibrateNeutralPose() }
  public func resetOffset() { motionSDK.resetPaddleCenter() }
  public func flipPaddleOffsetSign() { motionSDK.flipPaddleOffsetSign() }
  public func zeroNeutralTilt() { calibrateCenter() }

  public var debugBLEBytes: Bool {
    get { motionSDK.debugBLEBytes }
    set { motionSDK.debugBLEBytes = newValue }
  }

  public var logBLEPacketsInDevMode: Bool {
    get { motionSDK.logBLEPacketsInDevMode }
    set { motionSDK.logBLEPacketsInDevMode = newValue }
  }

  public var bleDevLog: [String] { motionSDK.bleDevLog }
  public func resetBLEProbe() { motionSDK.resetBLEProbe() }
  public var bleByteProbe: BLEByteProbe { motionSDK.bleByteProbe }
  public var debugParserClick: Bool { motionSDK.input.primaryAction }
  public var debugBLEButtonB1: UInt8 { motionSDK.lastButtonByte }
  public func clearBLEDevLog() { motionSDK.clearBLEDevLog() }

  private func presentCalibrationPromptIfNeeded() {
    guard !autoCalibDoneForConnection else { return }
    showsCalibrationPrompt = true
    autoCalibrationState = .awaitingUser
  }

  private func resetAutoCalibrationSession() {
    autoCalibDoneForConnection = false
    autoCalibrationState = .idle
    showsCalibrationPrompt = false
  }
}

public typealias MotionInputProvider = TrikiInputAdapter
