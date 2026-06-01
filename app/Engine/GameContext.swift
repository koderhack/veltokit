import Foundation

enum PixelColor: UInt8, Equatable {
  case black, darkGray, road, grass, white, cyan, magenta, green, yellow, red, navy, wood
}

enum DrawCommand: Equatable {
  case rect(x: Int, y: Int, width: Int, height: Int, color: PixelColor)
  case text(value: String, x: Int, y: Int, color: PixelColor)
}

/// Bufor rysowania 160×90 (pixel canvas).
final class GameContext {
  static let width = 160
  static let height = 90
  static let pixelTopInset = 10

  private(set) var commands: [DrawCommand] = []
  var commandSnapshot: [DrawCommand] { Array(commands) }

  func clear() {
    commands.removeAll(keepingCapacity: true)
  }

  func rect(x: Int, y: Int, width: Int, height: Int, color: PixelColor = .white) {
    commands.append(.rect(x: x, y: y, width: width, height: height, color: color))
  }

  func text(_ string: String, x: Int, y: Int, color: PixelColor = .white) {
    commands.append(.text(value: string, x: x, y: y, color: color))
  }
}
