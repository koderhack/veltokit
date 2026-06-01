import Foundation

/// Pozycja tyczkowanej lotki na tarczy (do rysowania).
struct DartBoardMarker: Equatable, Codable {
  var gridX: Double
  var gridY: Double
}

/// Lotka w locie — interpolacja z łukiem (jak Kinect / telewizyjny dart).
struct DartFlightAnimation: Equatable {
  let fromX: Double
  let fromY: Double
  let toX: Double
  let toY: Double
  let duration: TimeInterval
  var elapsed: TimeInterval

  var isFinished: Bool { elapsed >= duration }

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

  var currentPosition: (x: Double, y: Double) {
    position(at: progress)
  }

  mutating func advance(deltaTime: TimeInterval) {
    elapsed += deltaTime
  }
}
