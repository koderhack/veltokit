import SwiftUI

/// Jednolite skalowanie siatki pikseli w prostokącie (np. celownik nad canvasem).
struct PixelGridFitLayout: Equatable {
  let scale: CGFloat
  let canvasSize: CGSize
  let origin: CGPoint
  /// Przesunięcie siatki przy trybie `croppedUniform`.
  var cropOrigin: CGPoint = .zero

  static func fit(gridWidth: Int, gridHeight: Int, in size: CGSize) -> PixelGridFitLayout {
    let gw = CGFloat(gridWidth)
    let gh = CGFloat(gridHeight)
    let scale = max(1, floor(min(size.width / gw, size.height / gh)))
    let canvasW = gw * scale
    let canvasH = gh * scale
    return PixelGridFitLayout(
      scale: scale,
      canvasSize: CGSize(width: canvasW, height: canvasH),
      origin: CGPoint(x: (size.width - canvasW) / 2, y: (size.height - canvasH) / 2)
    )
  }

  func point(gridX: Double, gridY: Double) -> CGPoint {
    CGPoint(
      x: origin.x + (CGFloat(gridX) - cropOrigin.x) * scale,
      y: origin.y + (CGFloat(gridY) - cropOrigin.y) * scale
    )
  }

  /// Ten sam kadr co `PixelCanvas` `.croppedUniform` — do nakładki celownika na TV.
  static func croppedUniform(source: CGRect, in size: CGSize) -> PixelGridFitLayout {
    let sw = source.width
    let sh = source.height
    let scale = max(1, floor(min(size.width / sw, size.height / sh)))
    let canvasW = sw * scale
    let canvasH = sh * scale
    return PixelGridFitLayout(
      scale: scale,
      canvasSize: CGSize(width: canvasW, height: canvasH),
      origin: CGPoint(x: (size.width - canvasW) / 2, y: (size.height - canvasH) / 2),
      cropOrigin: source.origin
    )
  }
}

enum PixelPalette {
  static func color(_ pixel: PixelColor) -> Color {
    switch pixel {
    case .black: return Color(red: 0.05, green: 0.05, blue: 0.10)
    case .darkGray: return Color(red: 0.18, green: 0.18, blue: 0.24)
    case .road: return Color(red: 0.22, green: 0.22, blue: 0.30)
    case .grass: return Color(red: 0.10, green: 0.35, blue: 0.18)
    case .white: return Color(red: 0.92, green: 0.94, blue: 1.0)
    case .cyan: return Color(red: 0.20, green: 0.95, blue: 1.0)
    case .magenta: return Color(red: 1.0, green: 0.25, blue: 0.75)
    case .green: return Color(red: 0.25, green: 1.0, blue: 0.45)
    case .yellow: return Color(red: 1.0, green: 0.92, blue: 0.25)
    case .red: return Color(red: 1.0, green: 0.30, blue: 0.30)
    case .navy: return Color(red: 0.06, green: 0.08, blue: 0.22)
    case .wood: return Color(red: 0.32, green: 0.20, blue: 0.12)
    }
  }
}

enum PixelCanvasDisplayMode: Equatable {
  case fit
  case portraitPhone
  /// Jednolite skalowanie wycinka siatki (np. tarcza na TV).
  case croppedUniform(source: CGRect)
}

struct PixelCanvas: View, Equatable {
  let commands: [DrawCommand]
  let gridWidth: Int
  let gridHeight: Int
  var displayMode: PixelCanvasDisplayMode = .portraitPhone

  static func == (lhs: PixelCanvas, rhs: PixelCanvas) -> Bool {
    lhs.commands == rhs.commands &&
      lhs.gridWidth == rhs.gridWidth &&
      lhs.gridHeight == rhs.gridHeight &&
      lhs.displayMode == rhs.displayMode
  }

  var body: some View {
    GeometryReader { geo in
      let layout = displayLayout(in: geo.size)
      pixelGrid(layout: layout)
        .frame(width: layout.canvasW, height: layout.canvasH)
        .position(x: geo.size.width / 2, y: geo.size.height / 2)
    }
    .background(Color.black)
    .drawingGroup(opaque: true)
  }

  private struct DisplayLayout {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let canvasW: CGFloat
    let canvasH: CGFloat
    let fontSize: CGFloat
    var cropOrigin: CGPoint = .zero
  }

  private func displayLayout(in size: CGSize) -> DisplayLayout {
    let gw = CGFloat(gridWidth)
    let gh = CGFloat(gridHeight)
    switch displayMode {
    case .fit:
      let scale = max(1, floor(min(size.width / gw, size.height / gh)))
      return DisplayLayout(
        scaleX: scale,
        scaleY: scale,
        canvasW: gw * scale,
        canvasH: gh * scale,
        fontSize: max(8, scale * 0.85)
      )
    case .portraitPhone:
      let scaleX = size.width / gw
      let scaleY = size.height / gh
      return DisplayLayout(
        scaleX: scaleX,
        scaleY: scaleY,
        canvasW: size.width,
        canvasH: size.height,
        fontSize: max(8, min(scaleX, scaleY) * 0.85)
      )
    case .croppedUniform(let source):
      let sw = source.width
      let sh = source.height
      let scale = max(1, floor(min(size.width / sw, size.height / sh)))
      return DisplayLayout(
        scaleX: scale,
        scaleY: scale,
        canvasW: sw * scale,
        canvasH: sh * scale,
        fontSize: max(8, scale * 0.85),
        cropOrigin: source.origin
      )
    }
  }

  private func pixelGrid(layout: DisplayLayout) -> some View {
    let sx = layout.scaleX
    let sy = layout.scaleY
    let fontSize = layout.fontSize
    return Canvas(rendersAsynchronously: false) { context, _ in
      context.fill(
        Path(CGRect(x: 0, y: 0, width: layout.canvasW, height: layout.canvasH)),
        with: .color(PixelPalette.color(.black))
      )

      for command in commands {
        switch command {
        case let .rect(x, y, width, height, color):
          let ox = CGFloat(x) - layout.cropOrigin.x
          let oy = CGFloat(y) - layout.cropOrigin.y
          let rect = CGRect(
            x: ox * sx,
            y: oy * sy,
            width: CGFloat(width) * sx,
            height: CGFloat(height) * sy
          )
          guard rect.maxX > 0, rect.maxY > 0,
                rect.minX < layout.canvasW, rect.minY < layout.canvasH else { continue }
          context.fill(Path(rect), with: .color(PixelPalette.color(color)))

        case let .text(value, x, y, color):
          let ox = CGFloat(x) - layout.cropOrigin.x
          let oy = CGFloat(y) - layout.cropOrigin.y
          let text = Text(value)
            .font(.system(size: fontSize, weight: .bold, design: .monospaced))
            .foregroundStyle(PixelPalette.color(color))
          context.draw(
            text,
            at: CGPoint(x: ox * sx, y: oy * sy),
            anchor: .topLeading
          )
        }
      }
    }
  }
}
