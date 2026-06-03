import Foundation
import CoreBluetooth
import Combine
import os

@MainActor
/// Warstwa BLE: skan, połączenie, reconnect, notify — stabilna pod wolniejsze radio i nowy firmware.
public final class TrikiBLEManager: NSObject, ObservableObject {
  public enum Status: String {
    case idle
    case bluetoothOff
    case scanning
    case connecting
    case discovering
    case connected
    case error
  }

  private static let lastPeripheralUUIDKey = "triki.ble.lastPeripheralUUID"

  private let nusService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
  private let nusRX = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
  private let nusTX = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

  @Published public private(set) var status: Status = .idle
  @Published public private(set) var centralState: CBManagerState = .unknown
  @Published public private(set) var isBluetoothReady: Bool = false
  @Published public private(set) var discovered: [DiscoveredPeripheral] = []
  @Published public private(set) var connectedName: String? = nil
  @Published public var devRawLog: [String] = []
  @Published public var logRXPacketsInDevMode = false
  @Published public var debugRXBytes = false

  public let byteProbe = BLEByteProbe()
  public var autoConnectWhenSingleLikelyMatch = false
  /// Automatyczny reconnect po nieoczekiwanym rozłączeniu.
  public var autoReconnectEnabled = true
  public var reconnectDelay: TimeInterval = 1.5

  private var central: CBCentralManager!
  private var activePeripheral: CBPeripheral?
  private var rxChar: CBCharacteristic?
  private var txChar: CBCharacteristic?
  private var didAutoConnectThisScan = false
  private var userInitiatedDisconnect = false
  private var reconnectTask: Task<Void, Never>?

  private let rxBytesSubject = PassthroughSubject<[UInt8], Never>()
  public var rxBytes: AnyPublisher<[UInt8], Never> { rxBytesSubject.eraseToAnyPublisher() }

  private let log = Logger(subsystem: "com.koderteam.gametriki", category: "TrikiBLE")

  public override init() {
    super.init()
    central = CBCentralManager(delegate: self, queue: nil)
  }

  public var isScanning: Bool { status == .scanning }

  public var centralStateLabel: String {
    "\(centralState.rawValue) (\(stateLabel(centralState)))"
  }

  public var cachedPeripheralUUID: UUID? {
    get {
      guard let s = UserDefaults.standard.string(forKey: Self.lastPeripheralUUIDKey) else { return nil }
      return UUID(uuidString: s)
    }
    set {
      if let id = newValue {
        UserDefaults.standard.set(id.uuidString, forKey: Self.lastPeripheralUUIDKey)
      } else {
        UserDefaults.standard.removeObject(forKey: Self.lastPeripheralUUIDKey)
      }
    }
  }

  public func startScan(clearList: Bool = true) {
    guard isBluetoothReady else {
      status = .bluetoothOff
      addDevLog("SCAN ✗ Bluetooth nie jest włączony")
      return
    }
    if clearList { discovered.removeAll() }
    didAutoConnectThisScan = false
    status = .scanning
    central.scanForPeripherals(withServices: nil, options: [
      CBCentralManagerScanOptionAllowDuplicatesKey: false,
    ])
    addDevLog("SCAN ▶")
    log.info("TrikiBLE scan started")
  }

  public func stopScan() {
    central.stopScan()
    if status == .scanning { status = .idle }
    addDevLog("SCAN ■ stop")
  }

  public func connect(_ item: DiscoveredPeripheral) {
    stopScan()
    reconnectTask?.cancel()
    userInitiatedDisconnect = false
    status = .connecting
    activePeripheral = item.peripheral
    activePeripheral?.delegate = self
    cachedPeripheralUUID = item.id
    central.connect(item.peripheral, options: nil)
    addDevLog("CONN ▶ \(item.name)")
  }

  public func connectCachedPeripheralIfAvailable() {
    guard let id = cachedPeripheralUUID else { return }
    let known = central.retrievePeripherals(withIdentifiers: [id])
    guard let peripheral = known.first else {
      startScan(clearList: false)
      return
    }
    let name = peripheral.name ?? "Triki"
    connect(
      DiscoveredPeripheral(
        id: peripheral.identifier,
        peripheral: peripheral,
        name: name,
        rssi: 0,
        isLikelyController: true
      )
    )
  }

  public func disconnect() {
    userInitiatedDisconnect = true
    reconnectTask?.cancel()
    guard let p = activePeripheral else { return }
    central.cancelPeripheralConnection(p)
  }

  public func sendInitAndStartIfReady() {
    guard activePeripheral != nil, let rx = rxChar else { return }
    write([0x01, 0x00], to: rx, type: .withResponse)
    write([0x20, 0x10, 0x00, 0xD0, 0x07, 0x34, 0x00, 0x03], to: rx, type: .withoutResponse)
    addDevLog("TX ▶ INIT + START")
  }

  public func writeHex(_ hex: String, withResponse: Bool) {
    guard let rx = rxChar else { return }
    let bytes = Hex.parse(hex)
    guard !bytes.isEmpty else { return }
    write(bytes, to: rx, type: withResponse ? .withResponse : .withoutResponse)
    addDevLog("TX ▶ \(Hex.format(bytes))")
  }

  private func write(_ bytes: [UInt8], to ch: CBCharacteristic, type: CBCharacteristicWriteType) {
    guard let p = activePeripheral else { return }
    p.writeValue(Data(bytes), for: ch, type: type)
  }

  private func scheduleReconnectIfNeeded() {
    guard autoReconnectEnabled, !userInitiatedDisconnect else { return }
    reconnectTask?.cancel()
    reconnectTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let ns = UInt64(self.reconnectDelay * 1_000_000_000)
      try? await Task.sleep(nanoseconds: ns)
      guard !self.userInitiatedDisconnect, self.status != .connected else { return }
      self.addDevLog("RECONN ▶")
      if self.cachedPeripheralUUID != nil {
        self.connectCachedPeripheralIfAvailable()
      } else {
        self.startScan(clearList: false)
      }
    }
  }

  private func enableNotificationsIfPossible() {
    guard let peripheral = activePeripheral, let txChar else { return }
    peripheral.setNotifyValue(true, for: txChar)
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

  private func isLikelyTriki(name: String) -> Bool {
    name.lowercased().contains("triki")
  }

  private func upsertDiscovery(peripheral: CBPeripheral, name: String, rssi: Int) {
    let likely = isLikelyTriki(name: name)
    let item = DiscoveredPeripheral(
      id: peripheral.identifier,
      peripheral: peripheral,
      name: name,
      rssi: rssi,
      isLikelyController: likely
    )

    if let idx = discovered.firstIndex(where: { $0.id == item.id }) {
      discovered[idx] = item
    } else {
      discovered.append(item)
      addDevLog("FOUND: \(name) rssi=\(rssi)")
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
    connect(only)
  }
}

extension TrikiBLEManager: CBCentralManagerDelegate {
  nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
    Task { @MainActor in
      centralState = central.state
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

  nonisolated public func centralManager(
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

  nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    Task { @MainActor in
      status = .discovering
      connectedName = peripheral.name
      cachedPeripheralUUID = peripheral.identifier
      addDevLog("CONN ✓ \(peripheral.name ?? "Unknown")")
      peripheral.discoverServices(nil)
    }
  }

  nonisolated public func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    Task { @MainActor in
      status = .error
      addDevLog("CONN ✗ \(error?.localizedDescription ?? "?")")
      scheduleReconnectIfNeeded()
    }
  }

  nonisolated public func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    Task { @MainActor in
      status = .idle
      connectedName = nil
      rxChar = nil
      txChar = nil
      activePeripheral = nil
      addDevLog("DISC ↯ \(error?.localizedDescription ?? "ok")")
      scheduleReconnectIfNeeded()
    }
  }
}

extension TrikiBLEManager: CBPeripheralDelegate {
  nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    Task { @MainActor in
      if let error {
        status = .error
        addDevLog("SRV ✗ \(error.localizedDescription)")
        return
      }
      guard let services = peripheral.services else { return }
      let nus = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
      if let match = services.first(where: { $0.uuid == nus }) {
        peripheral.discoverCharacteristics(
          [
            CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"),
            CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"),
          ],
          for: match
        )
        return
      }
      status = .error
      addDevLog("SRV ? brak NUS")
    }
  }

  nonisolated public func peripheral(
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
        if ch.uuid == nusRX { rxChar = ch }
        if ch.uuid == nusTX { txChar = ch }
      }
      enableNotificationsIfPossible()
      if rxChar != nil, txChar != nil {
        status = .connected
        sendInitAndStartIfReady()
      }
    }
  }

  nonisolated public func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateNotificationStateFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    Task { @MainActor in
      if error == nil, characteristic.isNotifying, status == .connected {
        sendInitAndStartIfReady()
      }
    }
  }

  nonisolated public func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if error != nil { return }
    guard characteristic.uuid == CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"),
          let data = characteristic.value,
          !data.isEmpty else { return }
    let bytes = [UInt8](data)
    Task { @MainActor in
      if debugRXBytes || logRXPacketsInDevMode {
        addDevLog("RX ◀ \(Hex.format(bytes))")
      }
      rxBytesSubject.send(bytes)
    }
  }
}

/// Urządzenie z listy skanowania.
public struct DiscoveredPeripheral: Identifiable, Equatable {
  public let id: UUID
  public let peripheral: CBPeripheral
  public var name: String
  public var rssi: Int
  public var isLikelyController: Bool
}

/// Kompatybilność wsteczna z wcześniejszym `BLEManager`.
public typealias BLEManager = TrikiBLEManager

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
