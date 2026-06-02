import Foundation

/// Pozycja tyczkowanej lotki na tarczy (do rysowania).
struct DartBoardMarker: Equatable, Codable {
  /// Przechowuje wartość `gridX` wykorzystywaną przez dany komponent.
  var gridX: Double
  /// Przechowuje wartość `gridY` wykorzystywaną przez dany komponent.
  var gridY: Double
}

/// Lotka w locie — interpolacja z łukiem (jak Kinect / telewizyjny dart).
struct DartFlightAnimation: Equatable {
  /// Przechowuje wartość `fromX` wykorzystywaną przez dany komponent.
  let fromX: Double
  /// Przechowuje wartość `fromY` wykorzystywaną przez dany komponent.
  let fromY: Double
  /// Przechowuje wartość `toX` wykorzystywaną przez dany komponent.
  let toX: Double
  /// Przechowuje wartość `toY` wykorzystywaną przez dany komponent.
  let toY: Double
  /// Przechowuje wartość `duration` wykorzystywaną przez dany komponent.
  let duration: TimeInterval
  /// Przechowuje wartość `elapsed` wykorzystywaną przez dany komponent.
  var elapsed: TimeInterval

  /// Przechowuje wartość `isFinished` wykorzystywaną przez dany komponent.
  var isFinished: Bool { elapsed >= duration }

  /// Przechowuje wartość `progress` wykorzystywaną przez dany komponent.
  var progress: Double {
    guard duration > 0 else { return 1 }
    return min(1, elapsed / duration)
  }

  /// Pozycja w siatce gry (łuk w górę w połowie lotu).
  func position(at t: Double) -> (x: Double, y: Double) {
    let u = min(1, max(0, t))
    let x = fromX + (toX - fromX) * u
    let arc = sin(u * .pi) * 10
    let y = fromY + (toY - fromY) * u - arc
    return (x, y)
  }

  /// Przechowuje wartość `currentPosition` wykorzystywaną przez dany komponent.
  var currentPosition: (x: Double, y: Double) {
    position(at: progress)
  }

  mutating func advance(deltaTime: TimeInterval) {
    elapsed += deltaTime
  }
}
