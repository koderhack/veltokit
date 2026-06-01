import Foundation

enum TrikiMotionProtocol {
  static let header: [UInt8] = [0x22, 0x00]
  static let sensorFrameLength = 14
  static let fullFrameLength = 16
  static let footerMarkers: Set<UInt8> = [0xF7, 0xF8]

  struct Sample {
    var sensors: TrikiSensors
    var hadFullFrame: Bool
    var flags: UInt8
  }

  static func drainFrames(from buffer: inout [UInt8]) -> [Sample] {
    var samples: [Sample] = []
    var cursor = 0
    let count = buffer.count

    while cursor < count {
      if let mini = tryParseMiniFrame(buffer: buffer, cursor: &cursor) {
        samples.append(mini)
        continue
      }
      if let full = tryParseFullFrame(buffer: buffer, cursor: &cursor) {
        samples.append(full)
        continue
      }

      guard let idx = findNextHeaderStart(in: buffer, from: cursor) else {
        cursor = count
        break
      }

      if idx > cursor {
        cursor = idx
      }

      if count - cursor < 2 { break }
      if buffer[cursor + 1] != header[1] {
        cursor += 1
        continue
      }
      if count - cursor < fullFrameLength { break }
      cursor += 1
    }

    if cursor > 0 {
      buffer.removeFirst(cursor)
    }

    return samples
  }

  private static func tryParseMiniFrame(buffer: [UInt8], cursor: inout Int) -> Sample? {
    guard buffer.count - cursor >= 2 else { return nil }
    guard footerMarkers.contains(buffer[cursor + 1]) else { return nil }
    guard buffer[cursor] != header[0] else { return nil }

    let flags = buffer[cursor]
    cursor += 2
    var s = TrikiSensors()
    s.click = (flags & 0x01) != 0
    s.shake = (flags & 0x02) != 0
    return Sample(sensors: s, hadFullFrame: false, flags: flags)
  }

  private static func tryParseFullFrame(buffer: [UInt8], cursor: inout Int) -> Sample? {
    let available = buffer.count - cursor
    guard available >= sensorFrameLength else { return nil }
    guard buffer[cursor] == header[0], buffer[cursor + 1] == header[1] else { return nil }
    if available == sensorFrameLength || hasNextSensorFrame(in: buffer, at: cursor) {
      let sample = parseSensorFrame(buffer, at: cursor, flags: 0)
      cursor += sensorFrameLength
      return sample
    }

    guard available >= fullFrameLength else { return nil }
    guard footerMarkers.contains(buffer[cursor + 15]) else {
      cursor += 2
      return nil
    }

    let sample = parseSensorFrame(buffer, at: cursor, flags: buffer[cursor + 14])
    cursor += fullFrameLength
    return sample
  }

  private static func parseSensorFrame(_ frame: [UInt8], at offset: Int, flags: UInt8) -> Sample {
    let ax = readInt16LE(frame, offset + 2)
    let ay = readInt16LE(frame, offset + 4)
    let gx = readInt16LE(frame, offset + 6)
    let gy = readInt16LE(frame, offset + 8)
    let gz = readInt16LE(frame, offset + 10)
    let rot = readInt16LE(frame, offset + 12)

    let gyroX = normalizeGyro(gx)
    let gyroY = normalizeGyro(gy)
    let gyroZ = normalizeGyro(gz)
    let motion = min(1, sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ))

    let sensors = TrikiSensors(
      tiltX: normalizeTilt(ax),
      tiltY: normalizeTilt(ay),
      gyroX: gyroX,
      gyroY: gyroY,
      gyroZ: gyroZ,
      rotation: normalizeRotation(rot),
      speed: normalizeSpeed(rot),
      motion: motion,
      click: (flags & 0x01) != 0,
      shake: (flags & 0x02) != 0
    )

    return Sample(sensors: sensors, hadFullFrame: true, flags: flags)
  }

  private static func hasNextSensorFrame(in buffer: [UInt8], at cursor: Int) -> Bool {
    buffer.count >= cursor + sensorFrameLength + 2 &&
      buffer[cursor + sensorFrameLength] == header[0] &&
      buffer[cursor + sensorFrameLength + 1] == header[1]
  }

  private static func findNextHeaderStart(in buffer: [UInt8], from start: Int) -> Int? {
    guard start < buffer.count else { return nil }
    var i = start
    while i < buffer.count {
      if buffer[i] == header[0] { return i }
      i += 1
    }
    return nil
  }

  private static func readInt16LE(_ bytes: [UInt8], _ offset: Int) -> Int16 {
    let lo = UInt16(bytes[offset])
    let hi = UInt16(bytes[offset + 1])
    return Int16(bitPattern: lo | (hi << 8))
  }

  static func normalizeTilt(_ v: Int16) -> Double {
    clamp(Double(v) / 80.0)
  }

  static func normalizeGyro(_ v: Int16) -> Double {
    clamp(Double(v) / 64.0)
  }

  static func normalizeRotation(_ v: Int16) -> Double {
    clamp(Double(v) / 48.0)
  }

  static func normalizeSpeed(_ v: Int16) -> Double {
    clamp(abs(Double(v)) / 96.0)
  }

  private static func clamp(_ v: Double) -> Double {
    min(1, max(-1, v))
  }
}
