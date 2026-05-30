import SwiftUI

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
    }
  }
}

/// Sposób wyświetlenia siatki 160×90 na ekranie telefonu.
enum PixelCanvasDisplayMode {
  /// Jednolita skala, bez obrotu (paski w pionie).
  case fit
  /// Pełny ekran pionowy: bez obrotu, dół gry (paletka) = dół telefonu.
  case portraitPhone
}

struct PixelCanvas: View {
  let commands: [DrawCommand]
  let gridWidth: Int
  let gridHeight: Int
  var frameIndex: UInt = 0
  var displayMode: PixelCanvasDisplayMode = .portraitPhone

  var body: some View {
    GeometryReader { geo in
      let layout = displayLayout(in: geo.size)
      pixelGrid(layout: layout)
        .frame(width: layout.canvasW, height: layout.canvasH)
        .position(x: geo.size.width / 2, y: geo.size.height / 2)
    }
    .background(Color.black)
    .id(frameIndex)
  }

  private struct DisplayLayout {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let canvasW: CGFloat
    let canvasH: CGFloat
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
        canvasH: gh * scale
      )
    case .portraitPhone:
      let scaleX = size.width / gw
      let scaleY = size.height / gh
      return DisplayLayout(
        scaleX: scaleX,
        scaleY: scaleY,
        canvasW: size.width,
        canvasH: size.height
      )
    }
  }

  private func pixelGrid(layout: DisplayLayout) -> some View {
    let sx = layout.scaleX
    let sy = layout.scaleY
    return Canvas(rendersAsynchronously: false) { context, _ in
      context.fill(
        Path(CGRect(x: 0, y: 0, width: layout.canvasW, height: layout.canvasH)),
        with: .color(PixelPalette.color(.black))
      )

      for command in commands {
        switch command {
        case let .rect(x, y, width, height, color):
          let rect = CGRect(
            x: CGFloat(x) * sx,
            y: CGFloat(y) * sy,
            width: CGFloat(width) * sx,
            height: CGFloat(height) * sy
          )
          context.fill(Path(rect), with: .color(PixelPalette.color(color)))

        case let .text(value, x, y, color):
          let text = Text(value)
            .font(.system(size: max(8, min(sx, sy) * 0.85), weight: .bold, design: .monospaced))
            .foregroundStyle(PixelPalette.color(color))
          context.draw(
            context.resolve(text),
            at: CGPoint(x: CGFloat(x) * sx, y: CGFloat(y) * sy),
            anchor: .topLeading
          )
        }
      }
    }
  }
}
