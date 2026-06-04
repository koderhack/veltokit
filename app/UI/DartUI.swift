import SwiftUI
import VeltoKit

/// Panel pilota — Triki steruje z telefonu (tarcza może być na TV).
struct DartPhonePilotPanel: View {
  /// Przechowuje wartość `isConnected` wykorzystywaną przez dany komponent.
  let isConnected: Bool
  /// Przechowuje wartość `isReceiving` wykorzystywaną przez dany komponent.
  let isReceiving: Bool
  /// Kolor statusu połączenia (tryb BLE).
  let linkIndicatorColor: Color
  /// Przechowuje wartość `motionEnergy` wykorzystywaną przez dany komponent.
  let motionEnergy: Double
  /// Przechowuje wartość `throwState` wykorzystywaną przez dany komponent.
  let throwState: DartThrowController.ThrowState
  /// Przechowuje wartość `playZoneBand` wykorzystywaną przez dany komponent.
  let playZoneBand: DartPlayZone.Band
  /// Przechowuje wartość `boardOnTV` wykorzystywaną przez dany komponent.
  let boardOnTV: Bool

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(NeonTheme.neonCyan)
        VStack(alignment: .leading, spacing: 2) {
          Text("STEROWANIE · TELEFON")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .foregroundStyle(NeonTheme.neonCyan)
          Text(boardOnTV
            ? "TV = tarcza · telefon = pilot (rzut od góry)"
            : "Triki nad tarczą · skieruj w dół na planszę")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
        }
        Spacer()
        Circle()
          .fill(linkIndicatorColor)
          .frame(width: 9, height: 9)
      }

      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("TRIKI")
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
          Text(throwState.phoneLabel)
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(throwState == .ready ? NeonTheme.neonYellow : .white)
        }
        Spacer()
        motionMeter
      }

      if playZoneBand != .unknown {
        DartPlayZoneBadge(band: playZoneBand, level: 0)
          .opacity(0.9)
      }

      Text(DartPlayZone.distanceExplanation)
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.45))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.black.opacity(0.72))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(NeonTheme.neonCyan.opacity(0.45), lineWidth: 1.5)
        )
    )
  }

  private var motionMeter: some View {
    VStack(alignment: .trailing, spacing: 3) {
      Text("RUCH")
        .font(.system(size: 8, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white.opacity(0.45))
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.12))
          Capsule()
            .fill(
              LinearGradient(
                colors: [NeonTheme.neonCyan, NeonTheme.neonGreen],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(4, geo.size.width * CGFloat(min(1, motionEnergy * 1.4))))
        }
      }
      .frame(width: 72, height: 8)
    }
  }
}

/// Odliczanie 5…1 przed startem rozgrywki.
struct DartStartCountdownOverlay: View {
  /// Przechowuje wartość `value` wykorzystywaną przez dany komponent.
  let value: Int
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  var scale: CGFloat = 1

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    Text("\(value)")
      .font(.system(size: 88 * scale, weight: .black, design: .rounded))
      .foregroundStyle(
        LinearGradient(
          colors: [NeonTheme.neonYellow, NeonTheme.neonOrange],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .neonGlow(NeonTheme.neonYellow, radius: 18 * scale)
      .padding(.horizontal, 40 * scale)
      .padding(.vertical, 24 * scale)
      .background(
        Circle()
          .fill(Color.black.opacity(0.55))
          .frame(width: 140 * scale, height: 140 * scale)
      )
      .transition(.scale.combined(with: .opacity))
  }
}

/// Opisuje struct `DartTurnChangeBanner` używany przez warstwę UI i logikę gry.
struct DartTurnChangeBanner: View {
  /// Przechowuje wartość `playerName` wykorzystywaną przez dany komponent.
  let playerName: String
  /// Przechowuje wartość `dartsLeft` wykorzystywaną przez dany komponent.
  let dartsLeft: Int

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    VStack(spacing: 10) {
      Text("ZMIANA GRACZA")
        .font(.system(size: 11, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonMagenta)
      Text(playerName.uppercased())
        .font(.system(size: 28, weight: .black, design: .monospaced))
        .foregroundStyle(.white)
      Text("\(dartsLeft) lotki · 501")
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(NeonTheme.neonYellow)
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.black.opacity(0.88))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              LinearGradient(
                colors: [NeonTheme.neonMagenta, NeonTheme.neonCyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 2.5
            )
        )
    )
    .shadow(color: NeonTheme.neonMagenta.opacity(0.45), radius: 24)
  }
}

/// Opisuje struct `TrikiTurnConfirmBanner` używany przez warstwę UI i logikę gry.
struct TrikiTurnConfirmBanner: View {
  /// Przechowuje wartość `playerName` wykorzystywaną przez dany komponent.
  let playerName: String

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "button.programmable")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(NeonTheme.neonYellow)
      Text("TWOJA TURA")
        .font(.system(size: 11, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonMagenta)
      Text(playerName.uppercased())
        .font(.system(size: 26, weight: .black, design: .monospaced))
        .foregroundStyle(.white)
      Text("Naciśnij przycisk na Triki")
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(NeonTheme.neonCyan)
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 22)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.black.opacity(0.9))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(NeonTheme.neonYellow.opacity(0.85), lineWidth: 2.5)
        )
    )
    .shadow(color: NeonTheme.neonYellow.opacity(0.35), radius: 20)
  }
}

/// Opisuje struct `DartSoloScoreBadge` używany przez warstwę UI i logikę gry.
struct DartSoloScoreBadge: View {
  /// Przechowuje wartość `score` wykorzystywaną przez dany komponent.
  let score: Int

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    Text("\(score)")
      .font(.system(size: 22, weight: .black, design: .rounded))
      .foregroundStyle(NeonTheme.neonYellow)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(scoreBackground(stroke: NeonTheme.neonYellow.opacity(0.55)))
  }
}

/// Opisuje struct `DartRosterScoreStrip` używany przez warstwę UI i logikę gry.
struct DartRosterScoreStrip: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: DartGame.HUD

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        ForEach(0 ..< hud.playerCount, id: \.self) { index in
          scoreChip(
            name: hud.playerNames.indices.contains(index) ? hud.playerNames[index] : DartPlayers.defaultName(index: index),
            score: hud.playerScores.indices.contains(index) ? hud.playerScores[index] : 0,
            active: hud.activePlayerIndex == index
          )
        }
      }
    }
    .frame(maxWidth: 220)
  }

  private func scoreChip(name: String, score: Int, active: Bool) -> some View {
    VStack(alignment: .trailing, spacing: 1) {
      Text(shortName(name))
        .font(.system(size: 8, weight: .heavy, design: .monospaced))
        .foregroundStyle(active ? NeonTheme.neonMagenta : .white.opacity(0.5))
        .lineLimit(1)
      Text("\(score)")
        .font(.system(size: 16, weight: .black, design: .rounded))
        .foregroundStyle(active ? NeonTheme.neonYellow : .white.opacity(0.85))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 5)
    .background(
      scoreBackground(stroke: active ? NeonTheme.neonMagenta.opacity(0.7) : Color.white.opacity(0.2))
    )
  }

  private func shortName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 8 else { return trimmed.uppercased() }
    return String(trimmed.prefix(7)).uppercased() + "…"
  }
}

/// Opisuje struct `DartDuoScoreStrip` używany przez warstwę UI i logikę gry.
struct DartDuoScoreStrip: View {
  /// Przechowuje wartość `hud` wykorzystywaną przez dany komponent.
  let hud: DartGame.HUD
  /// Przechowuje wartość `player1Name` wykorzystywaną przez dany komponent.
  let player1Name: String
  /// Przechowuje wartość `player2Name` wykorzystywaną przez dany komponent.
  let player2Name: String

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    DartRosterScoreStrip(hud: hud)
  }
}

private func scoreBackground(stroke: Color) -> some View {
  RoundedRectangle(cornerRadius: 6)
    .fill(Color.black.opacity(0.45))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(stroke, lineWidth: 2)
    )
}

/// Wskaźnik dystansu od ekranu (5 pasków + etykieta).
struct DartPlayZoneBadge: View {
  /// Przechowuje wartość `band` wykorzystywaną przez dany komponent.
  let band: DartPlayZone.Band
  /// Przechowuje wartość `level` wykorzystywaną przez dany komponent.
  let level: Int

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    HStack(spacing: 6) {
      HStack(spacing: 2) {
        ForEach(1 ... 5, id: \.self) { index in
          RoundedRectangle(cornerRadius: 1)
            .fill(index <= level ? barColor : Color.white.opacity(0.15))
            .frame(width: 5, height: 8)
        }
      }
      Text(band.rawValue)
        .font(.system(size: 9, weight: .heavy, design: .monospaced))
        .foregroundStyle(barColor)
    }
  }

  private var barColor: Color {
    switch band {
    case .good: return NeonTheme.neonGreen
    case .close, .far: return NeonTheme.neonOrange
    case .unknown: return .white.opacity(0.45)
    }
  }
}

/// Wektorowy cel — puste kółko, po cofnięciu ręki wypełnione.
struct DartAimCircle: View {
  /// Przechowuje wartość `primed` wykorzystywaną przez dany komponent.
  let primed: Bool
  /// Przechowuje wartość `feedbackLabel` wykorzystywaną przez dany komponent.
  let feedbackLabel: String?
  /// Przechowuje wartość `diameter` wykorzystywaną przez dany komponent.
  var diameter: CGFloat = 44

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    let ringColor: Color = {
      if feedbackLabel == "MISS" { return .red }
      if feedbackLabel != nil, feedbackLabel != "MISS" { return NeonTheme.neonGreen }
      if primed { return NeonTheme.neonYellow }
      return NeonTheme.neonCyan
    }()
    let line = max(2, diameter * 0.06)

    ZStack {
      Circle()
        .strokeBorder(ringColor, lineWidth: primed ? line * 1.35 : line)
        .background(
          Circle()
            .fill(primed ? ringColor.opacity(0.5) : Color.clear)
        )
        .frame(width: diameter, height: diameter)
        .shadow(color: ringColor.opacity(0.5), radius: primed ? diameter * 0.2 : diameter * 0.1)

      Circle()
        .stroke(Color.white.opacity(0.4), lineWidth: max(1, line * 0.45))
        .frame(width: diameter * 0.2, height: diameter * 0.2)
    }
    .animation(.easeOut(duration: 0.12), value: primed)
    .animation(.easeOut(duration: 0.15), value: feedbackLabel)
  }
}

/// Komunikat po rzucie (telefon + TV) — jak feedback w quizie.
struct DartShotFeedbackCard: View {
  /// Przechowuje wartość `pointsLine` wykorzystywaną przez dany komponent.
  let pointsLine: String
  /// Przechowuje wartość `detailLine` wykorzystywaną przez dany komponent.
  let detailLine: String?
  /// Przechowuje wartość `isMiss` wykorzystywaną przez dany komponent.
  let isMiss: Bool
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  var scale: CGFloat = 1

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    let accent = isMiss ? Color.red : NeonTheme.neonGreen
    VStack(spacing: 10 * scale) {
      Text(pointsLine)
        .font(.system(size: 42 * scale, weight: .black, design: .rounded))
        .foregroundStyle(accent)
        .neonGlow(accent, radius: 12 * scale)
      if let detailLine, !detailLine.isEmpty {
        Text(detailLine.uppercased())
          .font(.system(size: 18 * scale, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white.opacity(0.9))
          .tracking(2)
      }
    }
    .padding(.horizontal, 32 * scale)
    .padding(.vertical, 22 * scale)
    .background(
      RoundedRectangle(cornerRadius: 12 * scale)
        .fill(Color.black.opacity(0.72))
        .overlay(
          RoundedRectangle(cornerRadius: 12 * scale)
            .stroke(
              LinearGradient(
                colors: [accent, accent.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 3 * scale
            )
        )
    )
    .shadow(color: accent.opacity(0.35), radius: 20 * scale)
    .transition(.scale(scale: 0.85).combined(with: .opacity))
  }
}

// MARK: - Lotka w locie / tyczki na tarczy

/// Opisuje struct `DartFlyingDartView` używany przez warstwę UI i logikę gry.
struct DartFlyingDartView: View {
  /// Przechowuje wartość `progress` wykorzystywaną przez dany komponent.
  let progress: Double
  /// Przechowuje wartość `diameter` wykorzystywaną przez dany komponent.
  var diameter: CGFloat = 28

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    let scale = 0.75 + 0.35 * (1 - progress)
    ZStack {
      Circle()
        .fill(
          RadialGradient(
            colors: [NeonTheme.neonYellow.opacity(0.35), .clear],
            center: .center,
            startRadius: 2,
            endRadius: diameter
          )
        )
        .frame(width: diameter * 2.2, height: diameter * 2.2)
        .offset(y: diameter * 0.4)

      Capsule()
        .fill(
          LinearGradient(
            colors: [Color.white, NeonTheme.neonYellow],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: diameter * 0.22, height: diameter * 1.1)
        .shadow(color: NeonTheme.neonYellow.opacity(0.8), radius: 8)

      Circle()
        .fill(NeonTheme.neonMagenta)
        .frame(width: diameter * 0.35, height: diameter * 0.35)
        .offset(y: -diameter * 0.55)
    }
    .scaleEffect(scale)
    .rotationEffect(.degrees(-18 + progress * 36))
    .animation(.linear(duration: 0.05), value: progress)
  }
}

/// Opisuje struct `DartStuckDartView` używany przez warstwę UI i logikę gry.
struct DartStuckDartView: View {
  /// Przechowuje wartość `diameter` wykorzystywaną przez dany komponent.
  var diameter: CGFloat = 14

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    ZStack {
      Circle()
        .fill(Color.black.opacity(0.5))
        .frame(width: diameter * 1.4, height: diameter * 1.4)
      Circle()
        .fill(NeonTheme.neonYellow)
        .frame(width: diameter * 0.55, height: diameter * 0.55)
      Capsule()
        .fill(Color.white.opacity(0.9))
        .frame(width: diameter * 0.18, height: diameter * 0.85)
        .offset(y: -diameter * 0.35)
    }
  }
}

/// Opisuje struct `DartBoardMarkersOverlay` używany przez warstwę UI i logikę gry.
struct DartBoardMarkersOverlay: View {
  /// Przechowuje wartość `markers` wykorzystywaną przez dany komponent.
  let markers: [DartBoardMarker]
  /// Przechowuje wartość `layout` wykorzystywaną przez dany komponent.
  let layout: PixelGridFitLayout
  /// Przechowuje wartość `markerSize` wykorzystywaną przez dany komponent.
  var markerSize: CGFloat = 14

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    ForEach(Array(markers.enumerated()), id: \.offset) { _, marker in
      DartStuckDartView(diameter: markerSize)
        .position(layout.point(gridX: marker.gridX, gridY: marker.gridY))
    }
  }
}

/// Tablica wyników na TV — styl Kinect / telewizyjny dart (501, gracze, lotki).
struct DartKinectTVScoreboard: View {
  /// Przechowuje wartość `playerNames` wykorzystywaną przez dany komponent.
  let playerNames: [String]
  /// Przechowuje wartość `playerScores` wykorzystywaną przez dany komponent.
  let playerScores: [Int]
  /// Przechowuje wartość `activePlayerIndex` wykorzystywaną przez dany komponent.
  let activePlayerIndex: Int
  /// Przechowuje wartość `dartsLeftInTurn` wykorzystywaną przez dany komponent.
  let dartsLeftInTurn: Int
  /// Przechowuje wartość `gameOver` wykorzystywaną przez dany komponent.
  let gameOver: Bool
  /// Przechowuje wartość `winnerName` wykorzystywaną przez dany komponent.
  let winnerName: String?
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  var scale: CGFloat = 1

  private var isMultiplayer: Bool { playerNames.count > 1 }

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    Group {
      if isMultiplayer {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12 * scale) {
            ForEach(0 ..< playerNames.count, id: \.self) { index in
              kinectPlayerPanel(
                slot: index + 1,
                name: playerNames[index],
                score: playerScores.indices.contains(index) ? playerScores[index] : 0,
                active: activePlayerIndex == index && !gameOver
              )
              .frame(minWidth: 140 * scale, maxWidth: 220 * scale)
            }
          }
          .padding(.horizontal, 4 * scale)
        }
      } else {
        kinectPlayerPanel(
          slot: 1,
          name: playerNames.first ?? "Gracz 1",
          score: playerScores.first ?? 0,
          active: !gameOver
        )
        .frame(maxWidth: 520 * scale)
      }
    }
    .padding(.horizontal, 28 * scale)
    .padding(.vertical, 14 * scale)
    .background(
      RoundedRectangle(cornerRadius: 12 * scale)
        .fill(Color.black.opacity(0.72))
        .overlay(
          RoundedRectangle(cornerRadius: 12 * scale)
            .stroke(NeonTheme.neonCyan.opacity(0.35), lineWidth: 2)
        )
    )
    .overlay(alignment: .top) {
      if gameOver, let winnerName {
        Text("\(winnerName.uppercased()) WYGRYWA")
          .font(.system(size: 22 * scale, weight: .black, design: .monospaced))
          .foregroundStyle(NeonTheme.neonYellow)
          .padding(.top, 8 * scale)
          .transition(.opacity)
      }
    }
  }

  private func kinectPlayerPanel(slot: Int, name: String, score: Int, active: Bool) -> some View {
    let accent = active ? NeonTheme.neonMagenta : Color.white.opacity(0.35)
    return VStack(alignment: .leading, spacing: 8 * scale) {
      HStack {
        Text("GRACZ \(slot)")
          .font(.system(size: 16 * scale, weight: .heavy, design: .monospaced))
          .foregroundStyle(accent)
        Spacer()
        if active {
          Text("TERAZ RZUCA")
            .font(.system(size: 12 * scale, weight: .black, design: .monospaced))
            .foregroundStyle(NeonTheme.neonYellow)
            .padding(.horizontal, 10 * scale)
            .padding(.vertical, 4 * scale)
            .background(Capsule().fill(NeonTheme.neonMagenta.opacity(0.35)))
        }
      }
      Text(name.uppercased())
        .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
      HStack(alignment: .lastTextBaseline, spacing: 10 * scale) {
        Text("\(score)")
          .font(.system(size: 56 * scale, weight: .black, design: .rounded))
          .foregroundStyle(active ? NeonTheme.neonYellow : .white.opacity(0.88))
          .neonGlow(active ? NeonTheme.neonYellow : .clear, radius: 8)
        Text("501")
          .font(.system(size: 14 * scale, weight: .heavy, design: .monospaced))
          .foregroundStyle(.white.opacity(0.35))
      }
      if active {
        DartDartsRemainingRow(total: 3, left: dartsLeftInTurn, scale: scale)
      }
    }
    .padding(16 * scale)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 10 * scale)
        .fill(active ? NeonTheme.neonMagenta.opacity(0.14) : Color.white.opacity(0.04))
        .overlay(
          RoundedRectangle(cornerRadius: 10 * scale)
            .stroke(active ? NeonTheme.neonMagenta : Color.white.opacity(0.15), lineWidth: active ? 3 : 1)
        )
    )
    .scaleEffect(active ? 1.02 : 1)
    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: active)
  }
}

/// Opisuje struct `DartDartsRemainingRow` używany przez warstwę UI i logikę gry.
struct DartDartsRemainingRow: View {
  /// Przechowuje wartość `total` wykorzystywaną przez dany komponent.
  let total: Int
  /// Przechowuje wartość `left` wykorzystywaną przez dany komponent.
  let left: Int
  /// Przechowuje wartość `scale` wykorzystywaną przez dany komponent.
  var scale: CGFloat = 1

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    HStack(spacing: 8 * scale) {
      Text("LOTKI")
        .font(.system(size: 11 * scale, weight: .heavy, design: .monospaced))
        .foregroundStyle(.white.opacity(0.5))
      ForEach(0..<total, id: \.self) { index in
        Image(systemName: index < left ? "circle.fill" : "circle")
          .font(.system(size: 14 * scale, weight: .bold))
          .foregroundStyle(index < left ? NeonTheme.neonCyan : .white.opacity(0.25))
      }
    }
  }
}
