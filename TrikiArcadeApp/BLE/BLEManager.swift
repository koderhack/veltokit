import Foundation
import CoreBluetooth
import Combine
import os

@MainActor
final class BLEManager: NSObject, ObservableObject {
  enum Status: String {
    case idle
    case bluetoothOff
    case scanning
    case connecting
    case discovering
    case connected
    case error
  }

  // NUS UUIDs
  private let nusService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
  private let nusRX = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // write
  private let nusTX = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // notify

  @Published private(set) var status: Status = .idle
  @Published private(set) var centralState: CBManagerState = .unknown
  @Published private(set) var isBluetoothReady: Bool = false
  @Published private(set) var discovered: [DiscoveredPeripheral] = []
  @Published private(set) var connectedName: String? = nil
  @Published var devRawLog: [String] = []
  @Published var logRXPacketsInDevMode = false

  /// Domyślnie wyłączone — flow jak w Żappce: user wybiera urządzenie z listy.
  var autoConnectWhenSingleLikelyMatch = false

  private var central: CBCentralManager!
  private var activePeripheral: CBPeripheral?
  private var rxChar: CBCharacteristic?
  private var txChar: CBCharacteristic?
  private var didAutoConnectThisScan = false

  private let rxBytesSubject = PassthroughSubject<[UInt8], Never>()
  var rxBytes: AnyPublisher<[UInt8], Never> { rxBytesSubject.eraseToAnyPublisher() }

  private let log = Logger(subsystem: "com.koderteam.gametriki", category: "BLE")

  override init() {
    super.init()
    central = CBCentralManager(delegate: self, queue: nil)
  }

  var isScanning: Bool { status == .scanning }

  var centralStateLabel: String {
    "\(centralState.rawValue) (\(stateLabel(centralState)))"
  }

  func startScan(clearList: Bool = true) {
    guard isBluetoothReady else {
      status = .bluetoothOff
      addDevLog("SCAN ✗ Bluetooth nie jest włączony (STATE: \(centralState.rawValue))")
      return
    }
    if clearList {
      discovered.removeAll()
    }
    didAutoConnectThisScan = false
    status = .scanning
    // NIE filtruj po NUS — Triki zwykle nie reklamuje UUID usług w advertising.
    // NUS widać dopiero po connect + discoverServices.
    central.scanForPeripherals(withServices: nil, options: [
      CBCentralManagerScanOptionAllowDuplicatesKey: false
    ])
    addDevLog("SCAN ▶ ALL devices (withServices: nil, NUS dopiero po połączeniu)")
    log.info("BLE scan started (no service filter, allow duplicates)")
  }

  func stopScan() {
    central.stopScan()
    if status == .scanning { status = .idle }
    addDevLog("SCAN ■ stop")
  }

  func connect(_ item: DiscoveredPeripheral) {
    stopScan()
    status = .connecting
    activePeripheral = item.peripheral
    activePeripheral?.delegate = self
    central.connect(item.peripheral, options: nil)
    addDevLog("CONN ▶ \(item.name)")
  }

  func disconnect() {
    guard let p = activePeripheral else { return }
    central.cancelPeripheralConnection(p)
  }

  func sendInitAndStartIfReady() {
    guard activePeripheral != nil, let rx = rxChar else { return }
    write([0x01, 0x00], to: rx, type: .withResponse)
    write([0x20, 0x10, 0x00, 0xD0, 0x07, 0x34, 0x00, 0x03], to: rx, type: .withoutResponse)
    addDevLog("TX ▶ INIT + START")
  }

  func writeHex(_ hex: String, withResponse: Bool) {
    guard let rx = rxChar else { return }
    let bytes = Hex.parse(hex)
    guard !bytes.isEmpty else { return }
    write(bytes, to: rx, type: withResponse ? .withResponse : .withoutResponse)
    addDevLog("TX ▶ \(Hex.format(bytes)) (\(withResponse ? "with" : "without") rsp)")
  }

  private func write(_ bytes: [UInt8], to ch: CBCharacteristic, type: CBCharacteristicWriteType) {
    guard let p = activePeripheral else { return }
    p.writeValue(Data(bytes), for: ch, type: type)
  }

  private func addDevLog(_ line: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    devRawLog.append("[\(ts)] \(line)")
    if devRawLog.count > 200 { devRawLog.removeFirst(devRawLog.count - 200) }
  }

  private func stateLabel(_ state: CBManagerState) -> String {
    switch state {
    case .unknown: return "unknown"
    case .resetting: return "resetting"
    case .unsupported: return "unsupported"
    case .unauthorized: return "unauthorized"
    case .poweredOff: return "poweredOff"
    case .poweredOn: return "poweredOn"
    @unknown default: return "?"
    }
  }

  /// Tylko podpowiedź UI — nie filtruje listy skanowania.
  private func isLikelyTriki(name: String) -> Bool {
    name.lowercased().contains("triki")
  }

  private func upsertDiscovery(
    peripheral: CBPeripheral,
    name: String,
    rssi: Int
  ) {
    let likely = isLikelyTriki(name: name)
    let item = DiscoveredPeripheral(
      id: peripheral.identifier,
      peripheral: peripheral,
      name: name,
      rssi: rssi,
      isLikelyController: likely
    )

    if let idx = discovered.firstIndex(where: { $0.id == item.id }) {
      let previous = discovered[idx]
      discovered[idx] = item
      if previous.rssi == item.rssi, previous.name == item.name {
        tryAutoConnectIfNeeded()
        return
      }
    } else {
      discovered.append(item)
      let tag = likely ? "LIKELY Triki" : "found"
      addDevLog("FOUND: \(name) rssi=\(rssi) [\(tag)]")
      log.info("FOUND \(name, privacy: .public) rssi=\(rssi) likely=\(likely)")
    }

    discovered.sort { a, b in
      if a.isLikelyController != b.isLikelyController { return a.isLikelyController }
      return a.rssi > b.rssi
    }

    tryAutoConnectIfNeeded()
  }

  private func tryAutoConnectIfNeeded() {
    guard autoConnectWhenSingleLikelyMatch else { return }
    guard status == .scanning, !didAutoConnectThisScan else { return }
    let likely = discovered.filter(\.isLikelyController)
    guard likely.count == 1, let only = likely.first else { return }
    didAutoConnectThisScan = true
    addDevLog("AUTO ▶ jedyny kandydat: \(only.name)")
    connect(only)
  }
}

struct DiscoveredPeripheral: Identifiable, Equatable {
  let id: UUID
  let peripheral: CBPeripheral
  var name: String
  var rssi: Int
  var isLikelyController: Bool
}

extension BLEManager: CBCentralManagerDelegate {
  nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
    Task { @MainActor in
      centralState = central.state
      addDevLog("STATE: \(central.state.rawValue) (\(stateLabel(central.state)))")

      switch central.state {
      case .poweredOn:
        isBluetoothReady = true
        if status == .bluetoothOff { status = .idle }
      default:
        isBluetoothReady = false
        if status == .scanning { central.stopScan() }
        status = .bluetoothOff
      }
    }
  }

  nonisolated func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    Task { @MainActor in
      let name = peripheral.name
        ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        ?? "Unknown"
      upsertDiscovery(peripheral: peripheral, name: name, rssi: RSSI.intValue)
    }
  }

  nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    Task { @MainActor in
      status = .discovering
      connectedName = peripheral.name
      addDevLog("CONN ✓ \(peripheral.name ?? "Unknown")")
      peripheral.discoverServices(nil)
    }
  }

  nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    Task { @MainActor in
      status = .error
      addDevLog("CONN ✗ \(error?.localizedDescription ?? "unknown error")")
    }
  }

  nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    Task { @MainActor in
      status = .idle
      connectedName = nil
      rxChar = nil
      txChar = nil
      activePeripheral = nil
      addDevLog("DISC ↯ \(error?.localizedDescription ?? "ok")")
    }
  }
}

extension BLEManager: CBPeripheralDelegate {
  nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    Task { @MainActor in
      if let error {
        status = .error
        addDevLog("SRV ✗ \(error.localizedDescription)")
        return
      }
      guard let services = peripheral.services else { return }
      if let nus = services.first(where: { $0.uuid == nusService }) {
        addDevLog("SRV ✓ NUS")
        peripheral.discoverCharacteristics([nusRX, nusTX], for: nus)
        return
      }
      let uuids = services.map(\.uuid.uuidString).joined(separator: ", ")
      addDevLog("SRV ? brak NUS; usługi: \(uuids)")
      status = .error
    }
  }

  nonisolated func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    Task { @MainActor in
      if let error {
        status = .error
        addDevLog("CHR ✗ \(error.localizedDescription)")
        return
      }
      guard let chars = service.characteristics else { return }
      for ch in chars {
        if ch.uuid == nusRX { rxChar = ch; addDevLog("CHR ✓ RX(write)") }
        if ch.uuid == nusTX { txChar = ch; addDevLog("CHR ✓ TX(notify)") }
      }
      if let txChar {
        peripheral.setNotifyValue(true, for: txChar)
      }
      if rxChar != nil, txChar != nil {
        status = .connected
        sendInitAndStartIfReady()
      }
    }
  }

  nonisolated func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    Task { @MainActor in
      if let error {
        addDevLog("NTF ✗ \(error.localizedDescription)")
      } else {
        addDevLog("NTF ✓ \(characteristic.isNotifying ? "on" : "off")")
      }
    }
  }

  nonisolated func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error {
      Task { @MainActor in addDevLog("RX ✗ \(error.localizedDescription)") }
      return
    }
    guard characteristic.uuid == nusTX, let data = characteristic.value, !data.isEmpty else { return }
    let bytes = [UInt8](data)
    Task { @MainActor in
      rxBytesSubject.send(bytes)
      if logRXPacketsInDevMode {
        addDevLog("RX ◀ \(Hex.format(bytes))")
      }
    }
  }
}

enum Hex {
  static func format(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
  }

  static func parse(_ text: String) -> [UInt8] {
    let cleaned = text
      .replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
      .replacingOccurrences(of: ",", with: " ")
      .replacingOccurrences(of: "\n", with: " ")
      .replacingOccurrences(of: "\t", with: " ")
    let parts = cleaned.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    var out: [UInt8] = []
    out.reserveCapacity(parts.count)
    for p in parts {
      let token = p.count == 1 ? "0" + p : p
      if let v = UInt8(token, radix: 16) {
        out.append(v)
      }
    }
    return out
  }
}
