import Foundation

/// Tryb wydajności notify firmware (wykrywany z odstępów między pakietami).
public enum TrikiBLEMode: String, Sendable, Equatable, CaseIterable {
  case fast
  case normal
  case lowPower
  case unknown
}

extension TrikiBLEMode {
  /// Maks. przerwa bez pakietu zanim UI uzna brak odbioru (zależnie od trybu).
  public var packetStaleSeconds: TimeInterval {
    switch self {
    case .fast: return 0.45
    case .normal: return 0.75
    case .lowPower: return 3.5
    case .unknown: return 0.55
    }
  }

  /// Krótka etykieta (PL) do HUD.
  public var statusLabel: String {
    switch self {
    case .fast: return "SZYBKI"
    case .normal: return "NORMALNY"
    case .lowPower: return "OSZCZĘDNY"
    case .unknown: return "—"
    }
  }
}
