import Foundation

/// Reprezentuje typ `PixelColor`.
enum PixelColor: UInt8, Equatable {
  case black, darkGray, road, grass, white, cyan, magenta, green, yellow, red, navy, wood
}

/// Reprezentuje typ `DrawCommand`.
enum DrawCommand: Equatable {
  case rect(x: Int, y: Int, width: Int, height: Int, color: PixelColor)
  case text(value: String, x: Int, y: Int, color: PixelColor)
}

/// Bufor rysowania 160×90 (pixel canvas).
final class GameContext {
/// Przechowuje wartosc `width`.
  static let width = 160
/// Przechowuje wartosc `height`.
  static let height = 90
/// Przechowuje wartosc `pixelTopInset`.
  static let pixelTopInset = 10

  private(set) var commands: [DrawCommand] = []
/// Przechowuje wartosc `commandSnapshot`.
  var commandSnapshot: [DrawCommand] { Array(commands) }

/// Wykonuje operacje `clear`.
  func clear() {
    commands.removeAll(keepingCapacity: true)
  }

/// Wykonuje operacje `rect`.
  func rect(x: Int, y: Int, width: Int, height: Int, color: PixelColor = .white) {
    commands.append(.rect(x: x, y: y, width: width, height: height, color: color))
  }

/// Wykonuje operacje `text`.
  func text(_ string: String, x: Int, y: Int, color: PixelColor = .white) {
    commands.append(.text(value: string, x: x, y: y, color: color))
  }
}
