import Foundation
import os

/// Wynik aktualizacji monitora — opcjonalna zmiana trybu po debounce.
public struct TrikiBLEModeTransition: Sendable, Equatable {
  public let previous: TrikiBLEMode
  public let current: TrikiBLEMode
  public let packetDelta: TimeInterval
}

/// Śledzi timing pakietów BLE i stabilnie wykrywa tryb fast / normal / low power.
public final class TrikiBLEMonitor: @unchecked Sendable {
  private let log = Logger(subsystem: "com.koderteam.gametriki", category: "TrikiBLEMonitor")
  private let lock = NSLock()

  /// Ostatni znany tryb (po debounce).
  public private(set) var currentMode: TrikiBLEMode = .unknown
  /// Ostatni zmierzony odstęp między pakietami (s).
  public private(set) var lastPacketDelta: TimeInterval = 0
  /// Czas ostatniego pakietu (s od 1970).
  public private(set) var lastTimestamp: TimeInterval = 0

  /// Włącza log delta + przejść trybu.
  public var debugLoggingEnabled = false

  /// Ile kolejnych pakietów z tym samym trybem przed commit (anty-flicker).
  public var requiredStablePackets = 3
  /// Ignoruj delty powyżej tej wartości przy klasyfikacji (przerwa / reconnect).
  public var maxClassifyDelta: TimeInterval = 3.0
  /// Po tylu sekundach bez pakietów → low power (UX idle).
  public var stalePacketThreshold: TimeInterval = 1.5

  private var candidateMode: TrikiBLEMode = .unknown
  private var candidateStreak = 0

  public init() {}

  /// Rejestruje przyjęcie pakietu; zwraca przejście trybu po debounce (jeśli było).
  @discardableResult
  public func recordPacket(at timestamp: TimeInterval) -> TrikiBLEModeTransition? {
    lock.lock()
    defer { lock.unlock() }

    var transition: TrikiBLEModeTransition?

    if lastTimestamp > 0 {
      let delta = timestamp - lastTimestamp
      lastPacketDelta = delta

      if debugLoggingEnabled {
        print(String(format: "[TrikiBLEMonitor] Δ=%.0fms", delta * 1000))
        log.debug("packet delta=\(delta, privacy: .public)s")
      }

      if delta >= 0.001, delta <= maxClassifyDelta {
        let sample = Self.classify(delta: delta)
        transition = applyCandidate(sample, delta: delta)
      } else if delta > maxClassifyDelta, debugLoggingEnabled {
        print("[TrikiBLEMonitor] skip classify (Δ=\(String(format: "%.2f", delta))s)")
      }
    }

    lastTimestamp = timestamp
    return transition
  }

  /// Wywołuj z pętli gry gdy długo nie było pakietów (idle / low power UX).
  public func evaluateStale(now: TimeInterval) -> TrikiBLEModeTransition? {
    lock.lock()
    defer { lock.unlock() }

    guard lastTimestamp > 0 else { return nil }
    let gap = now - lastTimestamp
    guard gap >= stalePacketThreshold else { return nil }
    return applyCandidate(.lowPower, delta: gap)
  }

  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    lastTimestamp = 0
    lastPacketDelta = 0
    currentMode = .unknown
    candidateMode = .unknown
    candidateStreak = 0
  }

  // MARK: - Classification

  public static func classify(delta: TimeInterval) -> TrikiBLEMode {
    if delta < 0.03 {
      return .fast
    }
    if delta < 0.2 {
      return .normal
    }
    return .lowPower
  }

  private func applyCandidate(_ sample: TrikiBLEMode, delta: TimeInterval) -> TrikiBLEModeTransition? {
    if sample == candidateMode {
      candidateStreak += 1
    } else {
      candidateMode = sample
      candidateStreak = 1
    }

    guard candidateStreak >= requiredStablePackets, sample != currentMode else {
      return nil
    }

    let previous = currentMode
    currentMode = sample
    candidateStreak = 0

    if debugLoggingEnabled {
      print("[TrikiBLEMonitor] mode \(previous.rawValue) → \(sample.rawValue) (Δ=\(String(format: "%.0f", delta * 1000))ms)")
    }
    log.info("BLE mode \(previous.rawValue, privacy: .public) → \(sample.rawValue, privacy: .public)")

    return TrikiBLEModeTransition(previous: previous, current: sample, packetDelta: delta)
  }
}
