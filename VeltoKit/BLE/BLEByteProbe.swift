import Foundation

/// Pomocnik do znalezienia bajtu/bitów przycisku — porównuje kolejne pakiety RX.
@MainActor
/// Represents blebyte probe.
public final class BLEByteProbe {
  /// Zmiana pojedynczego bajtu między kolejnymi pakietami.
  public struct ByteChange: Equatable, Sendable {
    /// Indeks bajtu w pakiecie.
    public let index: Int
    /// Poprzednia wartość bajtu.
    public let from: UInt8
    /// Nowa wartość bajtu.
    public let to: UInt8

    /// Zwraca maskę, jeśli zmienił się dokładnie jeden bit.
    public var singleBitMask: UInt8? {
      let xor = from ^ to
      guard xor != 0, xor & (xor - 1) == 0 else { return nil }
      return xor
    }
  }

  /// Zdarzenie zmiany stanu bajtu.
  public struct EdgeEvent: Identifiable, Sendable {
    /// Unikalny identyfikator zdarzenia.
    public let id = UUID()
    /// Indeks bajtu w pakiecie.
    public let index: Int
    /// Poprzednia wartość bajtu.
    public let from: UInt8
    /// Nowa wartość bajtu.
    public let to: UInt8
    /// Czas wykrycia zmiany.
    public let at: Date
  }

  /// Ostatnio zarejestrowany pakiet bajtów.
  private(set) public var lastBytes: [UInt8] = []
  private var lastValuesByIndex: [Int: UInt8] = [:]

  /// Ostatni pakiet w formacie HEX.
  public private(set) var lastPacketHex = "—"
  /// Lista zmian wykrytych dla ostatniego pakietu.
  public private(set) var lastChanges: [ByteChange] = []
  /// Ostatnie zdarzenia krawędzi 0→1 i 1→0.
  public private(set) var edgeEvents: [EdgeEvent] = []
  /// Ostatnie linie logu diagnostycznego.
  public private(set) var recentLines: [String] = []

  private let maxLines = 80
  private let maxEdges = 40

  /// Indeksy, które zmieniały się przy przejściu 0→1 (kandydaci na przycisk).
  public var risingZeroToOneIndices: [Int] {
    Array(
      Set(edgeEvents.filter { $0.from == 0 && $0.to == 1 }.map(\.index))
    ).sorted()
  }

  /// Tworzy nowy analizator zmian pakietów BLE.
  public init() {}

  /// Czyści stan analizatora i historię.
  public func reset() {
    lastBytes = []
    lastValuesByIndex = [:]
    lastPacketHex = "—"
    lastChanges = []
    edgeEvents = []
    recentLines = []
  }

  /// Zasila analizator kolejnym pakietem bajtów.
  ///
  /// - Parameter bytes: Pakiet bajtów RX.
  /// - Returns: Lista wykrytych zmian bajtów względem poprzedniego pakietu.
  @discardableResult
  /// Handles `ingest`.
  ///
  /// - Parameters:
  ///   - bytes: Input used by this operation.
  /// - Returns: Result produced by this operation.
  public func ingest(_ bytes: [UInt8]) -> [ByteChange] {
    guard !bytes.isEmpty else { return [] }

    lastPacketHex = Hex.format(bytes)
    var changes: [ByteChange] = []

    if lastBytes.isEmpty {
      for (i, b) in bytes.enumerated() {
        changes.append(ByteChange(index: i, from: 0, to: b))
        noteLine("INIT [\(i)] = \(b) (0x\(String(format: "%02X", b)))")
        trackEdge(index: i, from: 0, to: b)
        lastValuesByIndex[i] = b
      }
      noteLine("Pierwszy pakiet — kliknij przycisk i patrz na CHG/EDGE")
      lastBytes = bytes
      lastChanges = changes
      return changes
    }

    let shared = min(lastBytes.count, bytes.count)
    for i in 0..<shared where lastBytes[i] != bytes[i] {
      let change = ByteChange(index: i, from: lastBytes[i], to: bytes[i])
      changes.append(change)
      logChange(change)
      trackEdge(index: i, from: lastBytes[i], to: bytes[i])
      lastValuesByIndex[i] = bytes[i]
    }

    if bytes.count > lastBytes.count {
      for i in lastBytes.count..<bytes.count {
        let change = ByteChange(index: i, from: 0, to: bytes[i])
        changes.append(change)
        logChange(change)
        trackEdge(index: i, from: 0, to: bytes[i])
        lastValuesByIndex[i] = bytes[i]
      }
    }

    lastBytes = bytes
    lastChanges = changes
    return changes
  }

  private func logChange(_ change: ByteChange) {
    var line = "CHG [\(change.index)] \(change.from)→\(change.to) (0x\(String(format: "%02X", change.from))→0x\(String(format: "%02X", change.to)))"
    if let mask = change.singleBitMask {
      let bit = mask.trailingZeroBitCount
      line += " · bit \(bit)"
    }
    if change.from == 0 && change.to == 1 {
      line += " · CLICK?"
    } else if change.to == 0 && change.from != 0 {
      line += " · release?"
    }
    noteLine(line)
  }

  private func trackEdge(index: Int, from: UInt8, to: UInt8) {
    guard from != to else { return }

    if to == 1 && from == 0 {
      let event = EdgeEvent(index: index, from: from, to: to, at: Date())
      edgeEvents.append(event)
      if edgeEvents.count > maxEdges {
        edgeEvents.removeFirst(edgeEvents.count - maxEdges)
      }
      noteLine("EDGE 🔥 idx=\(index) 0→1")
    }

    let mask = from ^ to
    if mask != 0, mask & (mask - 1) == 0, !(from == 0 && to == 1) {
      noteLine("EDGE bit idx=\(index) bit=\(mask.trailingZeroBitCount) \(from)→\(to)")
    }
  }

  private func noteLine(_ line: String) {
    recentLines.append(line)
    if recentLines.count > maxLines {
      recentLines.removeFirst(recentLines.count - maxLines)
    }
  }
}
