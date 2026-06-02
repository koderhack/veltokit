import Foundation

/// Pixelowa hala dartowa (widok 3D) — publiczność z boków, światła, parkiet.
enum DartArenaScene {
  private static let w = GameContext.width
  private static let h = GameContext.height

  /// Renderuje tło i otoczenie areny wokół tarczy dartowej.
  ///
  /// - Parameters:
  ///   - context: Docelowy kontekst rasteryzacji pikselowej.
  ///   - boardCenterX: Pozycja X środka tarczy.
  ///   - boardCenterY: Pozycja Y środka tarczy.
  ///   - boardRadius: Promień tarczy.
  ///   - animTick: Licznik animacji używany do subtelnych efektów sceny.
  static func render(
    context: GameContext,
    boardCenterX: Double,
    boardCenterY: Double,
    boardRadius: Double,
    animTick: UInt
  ) {
    fillBackground(context: context)
    drawBackWall(context: context, boardCenterX: boardCenterX, boardCenterY: boardCenterY, boardRadius: boardRadius)
    drawCeiling(context: context, boardCenterX: boardCenterX, animTick: animTick)
    drawSpotlights(context: context, boardCenterX: boardCenterX, boardCenterY: boardCenterY)
    drawSideStands(context: context, side: .left, animTick: animTick)
    drawSideStands(context: context, side: .right, animTick: animTick)
    drawFloor(context: context, boardCenterX: boardCenterX, boardCenterY: boardCenterY, boardRadius: boardRadius)
    drawBoardGlow(context: context, boardCenterX: boardCenterX, boardCenterY: boardCenterY, boardRadius: boardRadius)
  }

  private enum Side { case left, right }

  private static func fillBackground(context: GameContext) {
    context.rect(x: 0, y: 0, width: w, height: h, color: .black)
    for y in 0..<h {
      let t = Double(y) / Double(h - 1)
      let band = y < 12 ? PixelColor.black : (t < 0.55 ? PixelColor.navy : PixelColor.road)
      context.rect(x: 0, y: y, width: w, height: 1, color: band)
    }
  }

  private static func drawBackWall(
    context: GameContext,
    boardCenterX: Double,
    boardCenterY: Double,
    boardRadius: Double
  ) {
    let wallBottom = Int((boardCenterY - boardRadius - 4).rounded(.down))
    guard wallBottom > 8 else { return }
    for y in 8..<wallBottom {
      for x in 0..<w {
        let dx = abs(Double(x) - boardCenterX) / boardCenterX
        let shade: PixelColor = hash(x, y) % 5 == 0 ? .navy : .darkGray
        let depth = 1.0 - Double(y) / Double(wallBottom) * 0.35
        if dx < 0.92 * depth {
          context.rect(x: x, y: y, width: 1, height: 1, color: shade)
        }
      }
    }
    // Pas startowy za tarczą
    let bandY = wallBottom
    context.rect(x: 0, y: bandY, width: w, height: 2, color: .wood)
  }

  private static func drawCeiling(context: GameContext, boardCenterX: Double, animTick: UInt) {
    for x in stride(from: 0, to: w, by: 18) {
      context.rect(x: x, y: 2, width: 1, height: 6, color: .darkGray)
      context.rect(x: x, y: 8, width: 14, height: 1, color: .darkGray)
    }
    let flicker = (animTick / 18) % 2 == 0
    for lx in [24, 56, 80, 104, 132] {
      let glow = flicker && hash(lx, Int(animTick)) % 3 == 0 ? PixelColor.yellow : PixelColor.white
      context.rect(x: lx, y: 4, width: 3, height: 2, color: glow)
      context.rect(x: lx + 1, y: 6, width: 1, height: 1, color: .yellow)
    }
    // Reflektor centralny
    context.rect(x: Int(boardCenterX) - 2, y: 3, width: 5, height: 2, color: .cyan)
  }

  private static func drawSpotlights(
    context: GameContext,
    boardCenterX: Double,
    boardCenterY: Double
  ) {
    let targetY = Int(boardCenterY.rounded())
    let targetX = Int(boardCenterX.rounded())
    for originX in [12, 148] {
      drawLightBeam(
        context: context,
        fromX: originX,
        fromY: 6,
        toX: targetX,
        toY: targetY,
        color: .cyan
      )
    }
    drawLightBeam(
      context: context,
      fromX: Int(boardCenterX),
      fromY: 4,
      toX: targetX,
      toY: targetY,
      color: .yellow
    )
  }

  private static func drawLightBeam(
    context: GameContext,
    fromX: Int,
    fromY: Int,
    toX: Int,
    toY: Int,
    color: PixelColor
  ) {
    let steps = max(abs(toX - fromX), abs(toY - fromY))
    guard steps > 0 else { return }
    for i in stride(from: 0, to: steps, by: 2) {
      let t = Double(i) / Double(steps)
      let x = fromX + Int(Double(toX - fromX) * t)
      let y = fromY + Int(Double(toY - fromY) * t)
      if hash(x, y) % 4 != 0 { continue }
      context.rect(x: x, y: y, width: 1, height: 1, color: color)
    }
  }

  private static func drawSideStands(context: GameContext, side: Side, animTick: UInt) {
    let rows = 10
    for row in 0..<rows {
      let depth = row
      let y = 12 + row * 6
      guard y < h - 14 else { continue }
      let tierWidth = 38 - depth * 2
      let x0: Int
      switch side {
      case .left:
        x0 = 1 + depth
      case .right:
        x0 = w - tierWidth - 1 - depth
      }
      // Balustrada
      context.rect(x: x0, y: y - 1, width: tierWidth, height: 1, color: .wood)
      context.rect(x: x0, y: y + 4, width: tierWidth, height: 1, color: .white)

      for col in 0..<tierWidth {
        let x = x0 + col
        if shouldDrawCrowdPixel(x: x, y: y, row: row, col: col, animTick: animTick) {
          context.rect(x: x, y: y, width: 1, height: 1, color: crowdColor(x: x, y: y, animTick: animTick))
          if row > 2, hash(x, y + 1) % 3 == 0 {
            context.rect(x: x, y: y + 1, width: 1, height: 1, color: .darkGray)
          }
        }
      }
    }
    // Słupy areny
    let pillarX = side == .left ? 42 : 115
    for py in 10..<(h - 12) {
      if py % 7 == 0 { continue }
      context.rect(x: pillarX, y: py, width: 2, height: 1, color: .wood)
    }
  }

  private static func shouldDrawCrowdPixel(x: Int, y: Int, row: Int, col: Int, animTick: UInt) -> Bool {
    let wave = Int(animTick / 6 + UInt(row))
    let base = hash(x + wave, y) % 10
    if base < 2 { return false }
    let cheer = (animTick + UInt(col)) % 24 < 4
    return cheer ? base < 9 : base < 7
  }

  private static func crowdColor(x: Int, y: Int, animTick: UInt) -> PixelColor {
    let palette: [PixelColor] = [.cyan, .magenta, .yellow, .green, .red, .white]
    let i = hash(x + Int(animTick / 10), y) % palette.count
    return palette[i]
  }

  private static func drawFloor(
    context: GameContext,
    boardCenterX: Double,
    boardCenterY: Double,
    boardRadius: Double
  ) {
    let floorTop = Int((boardCenterY + boardRadius + 2).rounded())
  guard floorTop < h - 2 else { return }
    let vanishX = boardCenterX
    let vanishY = Double(floorTop) + 4

    for y in floorTop..<h {
      let t = Double(y - floorTop) / Double(h - floorTop)
      let halfWidth = 12 + t * 78
      let left = Int(vanishX - halfWidth)
      let right = Int(vanishX + halfWidth)
      for x in max(0, left)...min(w - 1, right) {
        let u = Double(x - left) / max(1, Double(right - left))
        let plank = Int(u * 14) % 2 == 0
        let shade: PixelColor = plank ? .wood : .road
        if hash(x, y) % 11 == 0 {
          context.rect(x: x, y: y, width: 1, height: 1, color: .darkGray)
        } else {
          context.rect(x: x, y: y, width: 1, height: 1, color: shade)
        }
      }
      if y % 5 == 0 {
        let lineLeft = Int(vanishX - halfWidth * 0.92)
        let lineRight = Int(vanishX + halfWidth * 0.92)
        context.rect(x: max(0, lineLeft), y: y, width: max(1, lineRight - lineLeft), height: 1, color: .black)
      }
    }

    // Ochełnienie ochepek (rzuca cień)
    let lineY = floorTop
    context.rect(x: 0, y: lineY, width: w, height: 1, color: .yellow)
  }

  private static func drawBoardGlow(
    context: GameContext,
    boardCenterX: Double,
    boardCenterY: Double,
    boardRadius: Double
  ) {
    let cx = Int(boardCenterX.rounded())
    let cy = Int(boardCenterY.rounded())
    let r = Int(boardRadius.rounded(.up)) + 3
    for py in (cy - r)...(cy + r) {
      for px in (cx - r)...(cx + r) {
        let dx = Double(px - cx)
        let dy = Double(py - cy)
        let d = sqrt(dx * dx + dy * dy)
        guard d > boardRadius, d < boardRadius + 3.5 else { continue }
        if hash(px, py) % 2 == 0 {
          context.rect(x: px, y: py, width: 1, height: 1, color: .yellow)
        }
      }
    }
  }

  private static func hash(_ a: Int, _ b: Int) -> Int {
    var x = UInt(bitPattern: a &* 374_761_393 &+ b &* 668_265_263)
    x = (x ^ (x >> 13)) &* 1_274_126_171
    return Int(x % 9_999)
  }
}
