import Combine
import Foundation
import VeltoKit

/// Bridge between `MotionSDK` and app-facing Triki input APIs.
///
/// The adapter exposes observable connection/calibration state and implements `InputProvider`
/// so UI, navigation, and games can consume motion data through one stable dependency.

/// App-level bridge exposing `MotionSDK` through UI-friendly state and calibration flows.
///
/// Use this adapter in SwiftUI layers that need observable BLE/motion status, calibration prompts,
/// and a stable `InputProvider` abstraction for game/navigation systems.
@MainActor
/// Reprezentuje typ `TrikiInputAdapter`.
public final class TrikiInputAdapter: InputProvider, ObservableObject {
  /// Underlying motion SDK instance responsible for BLE connection and sensor parsing.
  public let motionSDK = MotionSDK()

  /// Current lifecycle state of auto-calibration UX.
  @Published public private(set) var autoCalibrationState: AutoCalibrationState = .idle
  /// Controls visibility of calibration prompt shown to the user.
  @Published public private(set) var showsCalibrationPrompt = false

  /// States describing calibration prompt and completion lifecycle.
  public enum AutoCalibrationState: Equatable {
    /// Calibration flow is not currently requested.
    case idle
    /// Device is ready and waiting for user-confirmed calibration.
    case awaitingUser
    /// Calibration was completed for the active connection.
    case done
  }

  /// Latest enriched motion input frame used by UI and game systems.
  public var liveInput: GameInput { motionSDK.liveInput }

  /// Indicates whether motion frames are currently received from device.
  public var isReceiving: Bool { motionSDK.isReceiving }
  /// Indicates whether BLE transport is currently connected.
  public var isConnected: Bool { motionSDK.isConnected }
  /// Convenience flag used by Triki UI to gate motion-based controls.
  public var isTrikiControlAvailable: Bool { isConnected && isReceiving }

  /// Runtime motion configuration forwarded to `MotionSDK`.
  public var config: MotionConfig {
    get { motionSDK.config }
    set { motionSDK.config = newValue }
  }

  private var autoCalibDoneForConnection = false

  /// Creates adapter with default SDK configuration.
  public init() {}

  /// Starts BLE connection flow.
  public func connect() { motionSDK.connect() }

  /// Stops BLE connection and resets per-session calibration flags.
  public func disconnect() {
    motionSDK.disconnect()
    resetAutoCalibrationSession()
  }

  /// Runs user-confirmed calibration and marks current session as calibrated.
  public func performCalibration() {
    motionSDK.calibrateNeutralPose()
    autoCalibDoneForConnection = true
    autoCalibrationState = .done
    showsCalibrationPrompt = false
  }

  /// Alias for automatic calibration entry points.
  public func performAutoCalibration() { performCalibration() }

  /// Displays calibration prompt when connection is active.
  public func presentCalibrationPrompt() {
    guard isConnected else { return }
    showsCalibrationPrompt = true
    autoCalibrationState = isReceiving ? .awaitingUser : .idle
  }

  /// Hides calibration prompt and marks calibration as intentionally skipped.
  public func skipCalibrationPrompt() {
    showsCalibrationPrompt = false
    autoCalibDoneForConnection = true
    autoCalibrationState = .idle
  }

  /// Switches motion interpretation profile.
  ///
  /// - Parameter mode: Target motion mode used by engine.
  public func setInputMode(_ mode: MotionMode) {
    motionSDK.setMode(mode)
  }

  /// Polls latest input frame and updates calibration prompt state when needed.
  ///
  /// - Parameter deltaTime: Optional frame delta in seconds.
  /// - Returns: Current normalized game input frame.
  /// - Side Effects: May trigger calibration prompt state transitions.
  public func pollInput(deltaTime: TimeInterval? = nil) -> GameInput {
    let input = motionSDK.pollInput(deltaTime: deltaTime)
    if isReceiving, isConnected, !autoCalibDoneForConnection {
      presentCalibrationPromptIfNeeded()
    }
    return input
  }

  /// Returns cached input without forcing a fresh BLE/parser update.
  public func snapshotInput() -> GameInput { motionSDK.snapshotInput() }

  /// Fully resets transport and adapter-side calibration state.
  public func resetInputState() {
    motionSDK.disconnect()
    resetAutoCalibrationSession()
  }

  /// Captures current neutral device pose as control center.
  public func calibrateCenter() { motionSDK.calibrateNeutralPose() }
  /// Resets paddle center offset in motion engine.
  public func resetOffset() { motionSDK.resetPaddleCenter() }
  /// Flips paddle offset sign to correct mirrored steering direction.
  public func flipPaddleOffsetSign() { motionSDK.flipPaddleOffsetSign() }
  /// Convenience alias used by older UI naming.
  public func zeroNeutralTilt() { calibrateCenter() }

  /// Enables verbose BLE byte diagnostics in parser pipeline.
  public var debugBLEBytes: Bool {
    get { motionSDK.debugBLEBytes }
    set { motionSDK.debugBLEBytes = newValue }
  }

  /// Enables packet logging intended for development diagnostics.
  public var logBLEPacketsInDevMode: Bool {
    get { motionSDK.logBLEPacketsInDevMode }
    set { motionSDK.logBLEPacketsInDevMode = newValue }
  }

  /// Raw diagnostic log emitted by BLE parser pipeline.
  public var bleDevLog: [String] { motionSDK.bleDevLog }
  /// Clears aggregated BLE byte probe buffers.
  public func resetBLEProbe() { motionSDK.resetBLEProbe() }
  /// Low-level BLE byte probe snapshot.
  public var bleByteProbe: BLEByteProbe { motionSDK.bleByteProbe }
  /// Indicates whether parser reported a click-like primary action.
  public var debugParserClick: Bool { motionSDK.input.primaryAction }
  /// Last raw B1 button byte observed from BLE payload.
  public var debugBLEButtonB1: UInt8 { motionSDK.lastButtonByte }
  /// Clears developer packet log buffer.
  public func clearBLEDevLog() { motionSDK.clearBLEDevLog() }

  /// Prompts calibration only once per connection after first valid data stream.
  private func presentCalibrationPromptIfNeeded() {
    guard !autoCalibDoneForConnection else { return }
    showsCalibrationPrompt = true
    autoCalibrationState = .awaitingUser
  }

  /// Resets adapter-local calibration session flags to defaults.
  private func resetAutoCalibrationSession() {
    autoCalibDoneForConnection = false
    autoCalibrationState = .idle
    showsCalibrationPrompt = false
  }
}

/// App-wide alias used by UI/environment objects for motion input dependency.
public typealias MotionInputProvider = TrikiInputAdapter
