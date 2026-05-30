import Foundation

/// Parser BLE: bloki 0x22 0x00, 3× int16 LE, normalizacja / 2000.
/// Drugi blok w pakiecie = żyroskop (pierwszy = akcelerometr, ignorowany).
public enum BLEGyroParser {
  public static let header: [UInt8] = [0x22, 0x00]
  public static let blockByteCount = 8
  public static let gyroDivisor = 2000.0
  public static let tiltDivisor = 80.0
  public static let normalizeDivisor = gyroDivisor

  public struct GyroTriple: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
  }

  /// int16 LE @ offset 2 (Triki NUS notify).
  public static func gyroRawFromPacket(_ data: [UInt8]) -> Double? {
    guard data.count >= 4 else { return nil }
    let lo = UInt16(data[2])
    let hi = UInt16(data[3])
    let value = Int16(littleEndian: Int16(bitPattern: lo | (hi << 8)))
    return Double(value)
  }

  public static func gyroRawYFromPacket(_ data: [UInt8]) -> Double? {
    gyroRawFromPacket(data)
  }

  /// Surowe int16 osi Y z **drugiego** bloku 0x22 (żyro) — bez dzielenia przez 2000.
  public static func latestGyroRawYUnscaled(from buffer: inout [UInt8]) -> Double? {
    var cursor = 0
    let count = buffer.count
    var blockIndex = 0
    var lastGyroY: Int16?

    while cursor + blockByteCount <= count {
      if buffer[cursor] != header[0] || buffer[cursor + 1] != header[1] {
        if let next = findHeader(in: buffer, from: cursor + 1) {
          cursor = next
          continue
        }
        break
      }
      let y = readInt16LE(buffer, cursor + 4)
      if blockIndex >= 1 {
        lastGyroY = y
      }
      blockIndex += 1
      cursor += blockByteCount
    }

    if cursor > 0 {
      buffer.removeSubrange(0..<cursor)
    }
    if buffer.count > 1024 {
      buffer.removeSubrange(0..<(buffer.count - 512))
    }

    guard let lastGyroY else { return nil }
    return Double(lastGyroY)
  }

  /// Ostatni żyro z bufora (preferuje drugi blok z ostatniej pary).
  public static func latestGyro(from buffer: inout [UInt8]) -> GyroTriple? {
    let blocks = drainGyroBlocks(from: &buffer)
    guard !blocks.isEmpty else { return nil }
    return blocks.count >= 2 ? blocks[1] : blocks[blocks.count - 1]
  }

  /// Pierwszy blok 2200 = akcelerometr (tilt); skala jak w TrikiMotionProtocol.
  public static func latestTilt(from buffer: inout [UInt8]) -> GyroTriple? {
    let blocks = drainGyroBlocks(from: &buffer)
    guard let first = blocks.first else { return nil }
    return scaledTiltBlock(first)
  }

  /// Parsuje bloki 2200 w buforze (kompaktuje bufor na końcu).
  public static func drainGyroBlocks(from buffer: inout [UInt8]) -> [GyroTriple] {
    var blocks: [GyroTriple] = []
    blocks.reserveCapacity(4)
    var cursor = 0
    let count = buffer.count

    while cursor + blockByteCount <= count {
      if buffer[cursor] != header[0] || buffer[cursor + 1] != header[1] {
        if let next = findHeader(in: buffer, from: cursor + 1) {
          cursor = next
          continue
        }
        cursor = count
        break
      }

      let v0 = readInt16LE(buffer, cursor + 2)
      let v1 = readInt16LE(buffer, cursor + 4)
      let v2 = readInt16LE(buffer, cursor + 6)
      blocks.append(
        GyroTriple(
          x: normalize(v0),
          y: normalize(v1),
          z: normalize(v2)
        )
      )
      cursor += blockByteCount
    }

    if blocks.isEmpty, count - cursor >= 14,
       buffer[cursor] == header[0], buffer[cursor + 1] == header[1],
       let triple = parseLegacy14ByteFrame(buffer, at: cursor) {
      blocks.append(triple)
      cursor += 14
    }

    if cursor > 0 {
      buffer.removeSubrange(0..<cursor)
    }
    if buffer.count > 1024 {
      buffer.removeSubrange(0..<(buffer.count - 512))
    }

    return blocks
  }

  private static func parseLegacy14ByteFrame(_ buffer: [UInt8], at offset: Int) -> GyroTriple? {
    guard buffer.count >= offset + 14 else { return nil }
    return GyroTriple(
      x: normalize(readInt16LE(buffer, offset + 8)),
      y: normalize(readInt16LE(buffer, offset + 10)),
      z: normalize(readInt16LE(buffer, offset + 12))
    )
  }

  private static func findHeader(in buffer: [UInt8], from start: Int) -> Int? {
    guard start < buffer.count - 1 else { return nil }
    var i = start
    while i < buffer.count - 1 {
      if buffer[i] == header[0], buffer[i + 1] == header[1] { return i }
      i += 1
    }
    return nil
  }

  private static func readInt16LE(_ bytes: [UInt8], _ offset: Int) -> Int16 {
    let lo = UInt16(bytes[offset])
    let hi = UInt16(bytes[offset + 1])
    return Int16(bitPattern: lo | (hi << 8))
  }

  public static func normalize(_ v: Int16, divisor: Double = gyroDivisor) -> Double {
    MotionMath.clamp(Double(v) / divisor)
  }

  public static func scaledTiltBlock(_ block: GyroTriple) -> GyroTriple {
    let scale = gyroDivisor / tiltDivisor
    return GyroTriple(x: block.x * scale, y: block.y * scale, z: block.z * scale)
  }
}
