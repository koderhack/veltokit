import Combine
import Foundation

@MainActor
/// Parser strumienia BLE do modelu `TrikiSensors` oraz impulsów klik/shake.
final class MotionParser: ObservableObject {
  /// Ostatni zdekodowany stan sensorów.
  @Published private(set) var sensors = TrikiSensors()
  /// Etykieta ostatniego dekodowania do podglądu DEV.
  @Published private(set) var lastDecodeLabel: String = "—"
  /// Ostatnie surowe ramki (tryb diagnostyczny).
  @Published private(set) var recentFrames: [[UInt8]] = []
  /// Wyłączone w grze — oszczędza RAM i CPU przy wysokim BLE notify.
  var retainRecentFrames = true

  /// Czas wygładzania kanału tilt.
  var tiltAlpha: Double = 1.0
  /// Czas wygładzania kanału gyro.
  var gyroAlpha: Double = 1.0
  /// Czas wygładzania kanału rotacji.
  var rotationAlpha: Double = 1.0
  /// Minimalna zmiana potrzebna do aktualizacji wartości.
  var noiseFloor: Double = 0.001

  /// Minimalny odstęp między impulsami kliknięcia.
  var clickCooldown: TimeInterval = 0.12
  /// Minimalny odstęp między impulsami shake.
  var shakeCooldown: TimeInterval = 0.10

  private var lastClickAt: TimeInterval = 0
  private var lastShakeAt: TimeInterval = 0
  private var pendingClick = false
  private var pendingShake = false
  private var rxBuffer: [UInt8] = []
  /// Ostatnio widziany `bytes[1]` (podgląd DEV).
  public private(set) var lastSeenButtonByte: UInt8 = 0

  private var smoothTiltX = 0.0
  private var smoothTiltY = 0.0
  private var smoothGyroX = 0.0
  private var smoothGyroY = 0.0
  private var smoothGyroZ = 0.0
  private var smoothRotation = 0.0

  /// Tylko buforuje — parsowanie w `flush()` (pętla gry).
  func enqueue(data: [UInt8]) {
    guard !data.isEmpty else { return }
    if retainRecentFrames {
      recentFrames.append(data)
      if recentFrames.count > 40 {
        recentFrames.removeFirst(recentFrames.count - 40)
      }
    }
    ingestBLEButtonEdges(from: data)
    rxBuffer.append(contentsOf: data)
    if rxBuffer.count > 2048 {
      rxBuffer.removeSubrange(0..<(rxBuffer.count - 1024))
    }
  }

  /// Opróżnia bufor i dekoduje dostępne ramki.
  func flush() {
    guard !rxBuffer.isEmpty else { return }
    let samples = TrikiMotionProtocol.drainFrames(from: &rxBuffer)
    guard !samples.isEmpty else { return }

    var lastFull: TrikiMotionProtocol.Sample?
    for sample in samples {
      if sample.hadFullFrame {
        lastFull = sample
      } else {
        applyImpulses(from: sample)
      }
    }
    if let lastFull {
      apply(lastFull, label: "")
    }
    applyBLEBlocks(from: &rxBuffer)
  }

  /// Wygodna ścieżka: enqueue + flush.
  func process(data: [UInt8]) {
    enqueue(data: data)
    flush()
  }

  /// Tylko klik / shake — bez kosztownego smoothingu (tryb paletki / Pong / Quiz).
  /// Odśwież tilt Y/X w trybie paletki (neutral ↑↓ bez pełnego flush).
  func refreshTiltSensors() {
    applyBLEBlocks(from: &rxBuffer)
  }

  /// Opróżnia tylko impulsy (klik/shake) bez pełnej ścieżki filtrowania.
  func flushImpulsesOnly() {
    guard !rxBuffer.isEmpty else { return }
    ingestBLEButtonEdgesFromBufferHead()
    let samples = TrikiMotionProtocol.drainFrames(from: &rxBuffer)
    let now = Date().timeIntervalSince1970
    for sample in samples {
      if sample.hadFullFrame {
        let s = sample.sensors
        if s.shake, now - lastShakeAt >= shakeCooldown {
          pendingShake = true
          lastShakeAt = now
        }
      } else {
        applyImpulses(from: sample)
      }
    }
    refreshClickSensorFlag()
  }

  /// Zwraca i czyści oczekujące impulsy klik/shake.
  func consumeImpulses() -> (click: Bool, shake: Bool) {
    let impulses = (click: pendingClick, shake: pendingShake)
    pendingClick = false
    pendingShake = false
    return impulses
  }

  /// Resetuje cały stan parsera i bufora RX.
  func resetStream() {
    rxBuffer.removeAll()
    smoothTiltX = 0
    smoothTiltY = 0
    smoothGyroX = 0
    smoothGyroY = 0
    smoothGyroZ = 0
    smoothRotation = 0
    lastDecodeLabel = "reset"
    sensors = TrikiSensors()
    recentFrames.removeAll()
    lastSeenButtonByte = 0
  }

  /// Czy klik był niedawno (DEV / HUD — impuls trwa ~1 klatkę).
  public var clickActiveForDisplay: Bool {
    let now = Date().timeIntervalSince1970
    return sensors.click || (now - lastClickAt) < 0.25
  }

  /// Podgląd `bytes[1]` — klik obsługuje `ButtonDetector` w MotionSDK.
  private func ingestBLEButtonEdges(from data: [UInt8]) {
    if data.count > BLEButtonDecoder.buttonIndex, data[0] == BLEButtonDecoder.packetHeader {
      lastSeenButtonByte = data[BLEButtonDecoder.buttonIndex]
    }
  }

  /// Gdy bufor jeszcze nie został skonsumowany przez ramki 14/16 B.
  private func ingestBLEButtonEdgesFromBufferHead() {
    guard !rxBuffer.isEmpty else { return }
    let scanLength = min(rxBuffer.count, 64)
    let head = Array(rxBuffer.prefix(scanLength))
    ingestBLEButtonEdges(from: head)
  }

  private func registerClickImpulse() {
    let now = Date().timeIntervalSince1970
    guard now - lastClickAt >= clickCooldown else { return }
    pendingClick = true
    lastClickAt = now
    var s = sensors
    s.click = true
    sensors = s
  }

  private func applyImpulses(from sample: TrikiMotionProtocol.Sample) {
    let now = Date().timeIntervalSince1970
    let s = sample.sensors
    // Klik tylko z BLE (bytes[1] edge) — flagi ruchu dają fałszywe „kliki” przy pochyleniu.
    if s.shake, now - lastShakeAt >= shakeCooldown {
      pendingShake = true
      lastShakeAt = now
    }
  }

  private func refreshClickSensorFlag() {
    let now = Date().timeIntervalSince1970
    guard sensors.click, now - lastClickAt > 0.25 else { return }
    var s = sensors
    s.click = false
    sensors = s
  }

  /// Pakiety 8 B (tilt + żyro) — aktualizacja między pełnymi ramkami 14/16 B.
  private func applyBLEBlocks(from buffer: inout [UInt8]) {
    guard !buffer.isEmpty else { return }
    let blocks = BLEGyroParser.drainGyroBlocks(from: &buffer)
    guard !blocks.isEmpty else { return }

    if let tilt = blocks.first.map({ BLEGyroParser.scaledTiltBlock($0) }) {
      smooth(&smoothTiltX, toward: tilt.x, alpha: tiltAlpha)
      smooth(&smoothTiltY, toward: tilt.y, alpha: tiltAlpha)
      smooth(&smoothRotation, toward: tilt.x, alpha: rotationAlpha)
    }

    let gyro = blocks.count >= 2 ? blocks[blocks.count - 1] : blocks[0]
    smooth(&smoothGyroX, toward: gyro.x)
    smooth(&smoothGyroY, toward: gyro.y)
    smooth(&smoothGyroZ, toward: gyro.z)

    publishSensorsFromSmoothState()
  }

  private func publishSensorsFromSmoothState(click: Bool? = nil, shake: Bool? = nil) {
    let motion = min(
      1,
      sqrt(
        smoothGyroX * smoothGyroX +
          smoothGyroY * smoothGyroY +
          smoothGyroZ * smoothGyroZ
      )
    )
    sensors = TrikiSensors(
      tiltX: clamp(smoothTiltX),
      tiltY: clamp(smoothTiltY),
      gyroX: clamp(smoothGyroX),
      gyroY: clamp(smoothGyroY),
      gyroZ: clamp(smoothGyroZ),
      rotation: clamp(smoothRotation),
      speed: clamp(abs(smoothRotation)),
      motion: motion,
      click: click ?? sensors.click,
      shake: shake ?? sensors.shake
    )
  }

  private func apply(_ sample: TrikiMotionProtocol.Sample, label: String) {
    let now = Date().timeIntervalSince1970
    let s = sample.sensors

    smooth(&smoothTiltX, toward: s.tiltX, alpha: tiltAlpha)
    smooth(&smoothTiltY, toward: s.tiltY, alpha: tiltAlpha)
    smooth(&smoothGyroX, toward: s.gyroX)
    smooth(&smoothGyroY, toward: s.gyroY)
    smooth(&smoothGyroZ, toward: s.gyroZ)
    smooth(&smoothRotation, toward: s.rotation, alpha: rotationAlpha)

    if s.click {
      registerClickImpulse()
    }
    if s.shake, now - lastShakeAt >= shakeCooldown {
      pendingShake = true
      lastShakeAt = now
    }

    publishSensorsFromSmoothState(
      click: clickActiveForDisplay,
      shake: pendingShake || s.shake
    )
    if !label.isEmpty {
      lastDecodeLabel = label
    }
  }

  private func smooth(_ value: inout Double, toward target: Double, alpha: Double? = nil) {
    let a = alpha ?? gyroAlpha
    if a >= 1.0 {
      value = target
      return
    }
    let d = target - value
    if abs(d) >= noiseFloor {
      value += a * d
    }
  }

  private func frameLabel(_ s: TrikiMotionProtocol.Sample) -> String {
    if s.hadFullFrame {
      let sen = s.sensors
      return String(
        format: "triki16 rot=%.2f gz=%.2f ax=%.2f spd=%.2f mot=%.2f",
        sen.rotation, sen.gyroZ, sen.tiltX, sen.speed, sen.motion
      )
    }
    return String(format: "triki2 flags=%02X", s.flags)
  }

  private func clamp(_ x: Double) -> Double {
    min(max(x, -1), 1)
  }

  private func decodeLegacyFrame(_ bytes: [UInt8]) -> TrikiMotionProtocol.Sample? {
    guard bytes.count >= 3 else { return nil }
    let ax = Int8(bitPattern: bytes[0])
    let ay = Int8(bitPattern: bytes[1])
    let flags = bytes[2]
    var s = TrikiSensors(
      tiltX: Double(ax) / 90.0,
      tiltY: Double(ay) / 90.0,
      rotation: Double(ax) / 90.0,
      click: (flags & 0x01) != 0,
      shake: (flags & 0x02) != 0
    )
    s.motion = min(1, abs(s.tiltX) + abs(s.tiltY))
    return TrikiMotionProtocol.Sample(sensors: s, hadFullFrame: true, flags: flags)
  }
}
