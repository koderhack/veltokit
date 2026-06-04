import Foundation
import os

// MARK: - Decode output (internal to motion pipeline)

/// Zdekodowane osie z pakietu BLE — przekazywane tylko do `TrikiMotionEngine`, nie do gier.
public struct ParsedMotionData: Sendable, Equatable {
  public var x: Float
  public var y: Float
  public var z: Float
  public var isValid: Bool
  /// Id presetu (diagnostyka): `"v2"`, `"legacy8"`, `"fallback"`, …
  public var presetID: String
  /// Zbocze przycisku (presety legacy).
  var buttonEdge: Bool
  /// Flaga shake z firmware (presety legacy).
  var firmwareShake: Bool

  public init(
    x: Float = 0,
    y: Float = 0,
    z: Float = 0,
    isValid: Bool = false,
    presetID: String = "invalid",
    buttonEdge: Bool = false,
    firmwareShake: Bool = false
  ) {
    self.x = x
    self.y = y
    self.z = z
    self.isValid = isValid
    self.presetID = presetID
    self.buttonEdge = buttonEdge
    self.firmwareShake = firmwareShake
  }
}

// MARK: - Parser

/// Parser BLE z presetami i bezpiecznym fallbackiem — gotowy na `parsePresetV3()`.
public final class TrikiParser: @unchecked Sendable {
  private let log = Logger(subsystem: "com.koderteam.gametriki", category: "TrikiParser")

  /// Włącza log hex + wartości zparsowane (konsola / Xcode).
  public var debugLoggingEnabled = false

  private var pendingFrames: [ParsedMotionData] = []
  private var rxBuffer = Data()
  private var lastButtonByte: UInt8 = 0
  private let lock = NSLock()

  public var maxBufferBytes = 2048

  public init() {}

  // MARK: - Main API

  /// Parsuje pojedynczy pakiet notify (wykrywa preset → dekoduje → fallback).
  public func parse(_ data: Data) -> ParsedMotionData {
    if debugLoggingEnabled {
      logHex(data)
    }

    let result: ParsedMotionData
    if Self.isPresetV2(data) {
      result = Self.parsePresetV2(data, lastButton: &lastButtonByte)
    } else if Self.isLegacyBlock8(data) {
      result = Self.parseLegacyBlock8(data, lastButton: &lastButtonByte)
    } else if Self.isLegacyFrame14(data) {
      result = Self.parseLegacyFrame14(data, lastButton: &lastButtonByte)
    } else if Self.isLegacyFrame16(data) {
      result = Self.parseLegacyFrame16(data, lastButton: &lastButtonByte)
    } else {
      result = Self.fallbackParse(data)
    }

    if debugLoggingEnabled {
      logParsed(result, sourceCount: data.count)
    } else if !result.isValid, data.count > 0 {
      log.debug("Invalid packet (\(data.count) B)")
    }

    return result
  }

  // MARK: - Streaming (BLE notify)

  /// Buforuje bajty i parsuje kompletne ramki przy `drainParsedFrames()`.
  public func append(_ bytes: [UInt8]) {
    guard !bytes.isEmpty else { return }
    lock.lock()
    defer { lock.unlock() }
    rxBuffer.append(contentsOf: bytes)
    if rxBuffer.count > maxBufferBytes {
      rxBuffer.removeFirst(rxBuffer.count - maxBufferBytes / 2)
    }
    let frames = extractFrames(from: &rxBuffer)
    pendingFrames.append(contentsOf: frames)
  }

  /// Zwraca zparsowane ramki od ostatniego drain (dla silnika ruchu).
  public func drainParsedFrames() -> [ParsedMotionData] {
    lock.lock()
    defer { lock.unlock() }
    let out = pendingFrames
    pendingFrames.removeAll(keepingCapacity: true)
    return out
  }

  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    rxBuffer.removeAll(keepingCapacity: false)
    pendingFrames.removeAll(keepingCapacity: false)
    lastButtonByte = 0
  }

  // MARK: - int16 LE

  /// Odczyt int16 little endian z bezpiecznym sprawdzeniem granic.
  public static func int16(_ data: Data, _ index: Int) -> Int16 {
    guard index >= 0, index + 1 < data.count else { return 0 }
    let lo = UInt16(data[index])
    let hi = UInt16(data[index + 1])
    return Int16(bitPattern: lo | (hi << 8))
  }

  // MARK: - Preset V2 (obserwowany firmware)

  public static func isPresetV2(_ data: Data) -> Bool {
    guard data.count >= 16, data.count <= 24 else { return false }
    if data.count >= 2 {
      return data[0] == 0x22
    }
    return true
  }

  public static func parsePresetV2(_ data: Data, lastButton: inout UInt8) -> ParsedMotionData {
    guard data.count >= 8 else {
      return ParsedMotionData(isValid: false, presetID: "v2-short")
    }

    let rawX = int16(data, 2)
    let rawY = int16(data, 4)
    let rawZ = int16(data, 6)
    let header = [UInt8](data.prefix(min(8, data.count)))
    let edge = BLEButtonDecoder.risingEdge(in: header, lastButton: &lastButton)

    return ParsedMotionData(
      x: Float(rawX) / 100.0,
      y: Float(rawY) / 100.0,
      z: Float(rawZ) / 100.0,
      isValid: true,
      presetID: "v2",
      buttonEdge: edge
    )
  }

  // MARK: - Legacy presets (poprzednie firmware / bloki NUS)

  static func isLegacyBlock8(_ data: Data) -> Bool {
    data.count >= 8 && data[0] == 0x22 && data[1] == 0x00
  }

  static func parseLegacyBlock8(_ data: Data, lastButton: inout UInt8) -> ParsedMotionData {
    guard data.count >= 8 else {
      return ParsedMotionData(isValid: false, presetID: "legacy8-short")
    }
    let rawX = int16(data, 2)
    let rawY = int16(data, 4)
    let rawZ = int16(data, 6)
    let bytes = [UInt8](data.prefix(8))
    let edge = BLEButtonDecoder.risingEdge(in: bytes, lastButton: &lastButton)

    return ParsedMotionData(
      x: Float(rawX) / 2000.0,
      y: Float(rawY) / 2000.0,
      z: Float(rawZ) / 2000.0,
      isValid: true,
      presetID: "legacy8",
      buttonEdge: edge
    )
  }

  static func isLegacyFrame14(_ data: Data) -> Bool {
    data.count == 14 && data[0] == 0x22 && data[1] == 0x00
  }

  static func isLegacyFrame16(_ data: Data) -> Bool {
    data.count >= 16 && data[0] == 0x22 && data[1] == 0x00
      && (data[15] == 0xF7 || data[15] == 0xF8)
  }

  static func parseLegacyFrame14(_ data: Data, lastButton: inout UInt8) -> ParsedMotionData {
    parseLegacySensorFrame(data, frameLength: 14, flags: 0, lastButton: &lastButton)
  }

  static func parseLegacyFrame16(_ data: Data, lastButton: inout UInt8) -> ParsedMotionData {
    let flags: UInt8 = data.count > 14 ? data[14] : 0
    return parseLegacySensorFrame(data, frameLength: 16, flags: flags, lastButton: &lastButton)
  }

  private static func parseLegacySensorFrame(
    _ data: Data,
    frameLength: Int,
    flags: UInt8,
    lastButton: inout UInt8
  ) -> ParsedMotionData {
    guard data.count >= frameLength, frameLength >= 14 else {
      return ParsedMotionData(isValid: false, presetID: "legacyFrame-short")
    }

    let tiltX = int16(data, 2)
    let tiltY = int16(data, 4)
    let gyroY = int16(data, 8)
    let rot = int16(data, 12)

    let edge = BLEButtonDecoder.risingEdge(
      in: [data[0], data[1]],
      lastButton: &lastButton
    )

    return ParsedMotionData(
      x: Float(tiltX) / 80.0,
      y: Float(gyroY != 0 ? gyroY : rot) / 2000.0,
      z: Float(tiltY) / 80.0,
      isValid: true,
      presetID: frameLength >= 16 ? "legacy16" : "legacy14",
      buttonEdge: edge || (flags & 0x01) != 0,
      firmwareShake: (flags & 0x02) != 0
    )
  }

  // MARK: - Fallback

  public static func fallbackParse(_ data: Data) -> ParsedMotionData {
    ParsedMotionData(
      x: 0,
      y: 0,
      z: 0,
      isValid: false,
      presetID: "fallback"
    )
  }

  // MARK: - Future presets

  /// Miejsce na `parsePresetV3` — dodaj `isPresetV3` + wpis w `parse(_:)` przed fallback.
  // static func isPresetV3(_ data: Data) -> Bool { ... }
  // static func parsePresetV3(_ data: Data) -> ParsedMotionData { ... }

  // MARK: - Private

  private func extractFrames(from buffer: inout Data) -> [ParsedMotionData] {
    guard !buffer.isEmpty else { return [] }

    if buffer.count >= 16, buffer.count <= 24, Self.isPresetV2(buffer) {
      let frame = buffer
      buffer.removeAll(keepingCapacity: false)
      return [parse(frame)]
    }

    var frames: [ParsedMotionData] = []
    var cursor = 0
    let bytes = [UInt8](buffer)

    while cursor < bytes.count {
      let slice = Data(bytes[cursor...])
      let presetLength = Self.detectedFrameLength(for: slice)
      guard presetLength > 0, cursor + presetLength <= bytes.count else {
        cursor += 1
        continue
      }
      let packet = Data(bytes[cursor..<(cursor + presetLength)])
      frames.append(parse(packet))
      cursor += presetLength
    }

    if cursor > 0 {
      buffer = Data(bytes[cursor...])
    }
    return frames
  }

  private static func detectedFrameLength(for data: Data) -> Int {
    if isLegacyBlock8(data) { return 8 }
    if isLegacyFrame14(data) { return 14 }
    if isLegacyFrame16(data) { return 16 }
    if isPresetV2(data) { return data.count }
    return 0
  }

  private func logHex(_ data: Data) {
    let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
    print("[TrikiParser] RX \(hex) (\(data.count) B)")
    log.debug("RX \(hex, privacy: .public)")
  }

  private func logParsed(_ result: ParsedMotionData, sourceCount: Int) {
    if result.isValid {
      print(
        String(
          format: "[TrikiParser] OK %@ x=%.3f y=%.3f z=%.3f (%d B)",
          result.presetID,
          result.x,
          result.y,
          result.z,
          sourceCount
        )
      )
    } else {
      print("[TrikiParser] INVALID \(result.presetID) (\(sourceCount) B)")
    }
    log.debug(
      "parsed preset=\(result.presetID, privacy: .public) valid=\(result.isValid) x=\(result.x) y=\(result.y) z=\(result.z)"
    )
  }
}
