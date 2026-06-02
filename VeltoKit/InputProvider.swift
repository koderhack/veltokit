import Foundation

/// Contracts for polling normalized game input from motion sources.
///
/// This file defines a lightweight boundary used by UI and gameplay layers to stay
/// independent from concrete sensor transports and SDK internals.

/// Shared input abstraction used by game/UI layers to consume normalized motion data.
///
/// Use this protocol when a screen or system should read motion input without coupling to
/// a specific transport (for example BLE-backed `MotionSDK` vs. test doubles).
@MainActor
/// Represents input provider.
public protocol InputProvider: AnyObject {
  /// Returns the latest sampled input frame.
  ///
  /// - Parameter deltaTime: Optional frame delta in seconds. Provide it when caller manages
  ///   a game loop tick; pass `nil` to let implementation infer timing.
  /// - Returns: Current normalized game input state.
  func pollInput(deltaTime: TimeInterval?) -> GameInput
}

/// Adds focused input provider helpers.
extension InputProvider {
  /// Default protocol implementation helpers.
  ///
  /// Use these helpers when caller code does not need to provide explicit frame timing.
  /// Convenience overload for callers that do not provide frame timing.
  ///
  /// - Returns: Current normalized game input state.
  public func pollInput() -> GameInput {
    pollInput(deltaTime: nil)
  }
}
