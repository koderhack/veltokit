import CoreGraphics
import Foundation
import VeltoKit

/// Geometria tarczy w siatce 160×90 (telefon + kadr TV).
enum DartBoardLayout {
  static let boardRadius = 35.0

  static var centerX: Double { Double(GameContext.width) / 2 }

  static var centerY: Double {
    Double(GameContext.pixelTopInset) + boardRadius + 6
  }

  /// Pełna scena 160×90 — hala + tarcza (Kinect / TV).
  static var tvCropRect: CGRect {
    CGRect(
      x: 0,
      y: 0,
      width: Double(GameContext.width),
      height: Double(GameContext.height)
    )
  }

  /// Kolejność jak na prawdziwej tarczy (góra = 20).
  static let segmentValues = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]

  static func sectorIndex(dx: Double, dy: Double) -> Int {
    let angle = atan2(dy, dx)
    var angle01 = (angle + .pi / 2) / (2 * .pi)
    if angle01 < 0 { angle01 += 1 }
    if angle01 >= 1 { angle01 -= 1 }
    return min(19, max(0, Int(angle01 * 20)))
  }

  /// Numery pól na pierścieniu (między triple a double).
  static func drawSegmentNumbers(
    context: GameContext,
    centerX: Double,
    centerY: Double,
    boardRadius: Double
  ) {
    let labelR = boardRadius * 0.76
    for sector in 0..<20 {
      let value = segmentValues[sector]
      let angle = (Double(sector) + 0.5) / 20.0 * (.pi * 2) - .pi / 2
      let x = centerX + labelR * cos(angle)
      let y = centerY + labelR * sin(angle)
      let label = "\(value)"
      let tx = Int(x.rounded()) - (label.count > 1 ? 5 : 2)
      let ty = Int(y.rounded()) - 3
      let color: PixelColor = sector.isMultiple(of: 2) ? .black : .yellow
      context.text(label, x: tx, y: ty, color: color)
    }

    let bullY = Int(centerY.rounded()) - 3
    let bullX = Int(centerX.rounded()) - 5
    context.text("25", x: bullX, y: bullY, color: .white)
  }
}

/// Dart — logika rzutu; UI w `DartGameView`.
final class DartGame: Game {
  /// Przechowuje wartość `name` wykorzystywaną przez dany komponent.
  let name = "Dart"
  /// Przechowuje wartość `inputProfile` wykorzystywaną przez dany komponent.
  let inputProfile: GameInputProfile = .dart

  /// Opisuje struct `HUD` używany przez warstwę UI i logikę gry.
  struct HUD: Equatable {
    var score: Int
    var playerCount: Int
    var playerScores: [Int]
    var playerNames: [String]
    var activePlayerIndex: Int
    var activePlayerName: String
    var dartsLeftInTurn: Int
    var legStartScore: Int
    var gameOver: Bool
    var winnerName: String?
    var lastHitLabel: String
    var feedbackLabel: String?
    var aimGridX: Double
    var aimGridY: Double
    var throwPrimed: Bool
    var throwState: DartThrowController.ThrowState
    var playZoneBand: DartPlayZone.Band
    var playZoneLevel: Int
    var playZoneHint: String
    var turnAnnouncement: String?
    var flightActive: Bool
    var flightGridX: Double
    var flightGridY: Double
    var flightProgress: Double
    var boardMarkers: [DartBoardMarker]
    /// Odliczanie 5…1 przed pierwszym rzutem; `nil` = gra trwa.
    var startCountdown: Int?
    /// Czeka na przycisk Triki, żeby rozpocząć turę (multi).
    var awaitingTurnStart: Bool

    var mode: DartPlayMode { playerCount > 1 ? .duo : .solo }
    var isMultiplayer: Bool { playerCount > 1 }
    var player1Score: Int { playerScores.indices.contains(0) ? playerScores[0] : 0 }
    var player2Score: Int { playerScores.indices.contains(1) ? playerScores[1] : 0 }
    var player1Name: String { playerNames.indices.contains(0) ? playerNames[0] : "Gracz 1" }
    var player2Name: String { playerNames.indices.contains(1) ? playerNames[1] : "Gracz 2" }
  }

  private struct ResolvedShot {
    let hitX: Double
    let hitY: Double
    let points: Int
    let label: String
    let isDoubleHit: Bool
    let onBoard: Bool
  }

  private let playerCount: Int
  private let playerNames: [String]
  private var grip: DartGripMapping

  private var playerScores: [Int] = []
  private var activePlayerIndex = 0
  private var turnSwitchPending = false
  private var dartsLeftInTurn = 3
  private var turnStartScore = 501
  private var gameOver = false
  private var winnerName: String?
  private var turnAnnouncement: String?
  private var turnAnnouncementTimer: TimeInterval = 0
  private var awaitingTurnStart = false
  private var turnGate = TrikiTurnStartGate()

  private let restoredMatch: DartMatchState?

  /// Inicjalizuje instancję i ustawia wymagane zależności.
  init(
    playerCount: Int = 1,
    playerNames: [String] = ["Gracz 1"],
    grip: DartGripMapping = .overhead,
    restoredMatch: DartMatchState? = nil
  ) {
    let count = DartPlayers.clampCount(playerCount)
    self.playerCount = count
    self.playerNames = DartPlayers.normalizedNames(playerNames, count: count)
    self.grip = grip
    self.restoredMatch = restoredMatch
  }

  /// Kompatybilność wsteczna (2 graczy).
  convenience init(
    mode: DartPlayMode,
    player1Name: String = "Gracz 1",
    player2Name: String = "Gracz 2",
    grip: DartGripMapping = .overhead,
    restoredMatch: DartMatchState? = nil
  ) {
    let count = mode == .solo ? 1 : 2
    self.init(
      playerCount: count,
      playerNames: [player1Name, player2Name],
      grip: grip,
      restoredMatch: restoredMatch
    )
  }

  /// Wykonuje operację `snapshot` w bieżącym kontekście gry/UI.
  func snapshot() -> DartMatchState {
    DartMatchState(
      playerCount: playerCount,
      playerScores: playerScores,
      activePlayerIndex: activePlayerIndex,
      dartsLeftInTurn: dartsLeftInTurn,
      turnStartScore: turnStartScore,
      gameOver: gameOver,
      winnerName: winnerName,
      lastHitLabel: lastHitLabel
    )
  }

  /// Wykonuje operację `applyGrip` w bieżącym kontekście gry/UI.
  func applyGrip(from axisMapping: MotionAxisMapping) {
    grip = DartGripMapping.from(axisMapping: axisMapping)
  }

  private(set) var currentHUD = HUD(
    score: 0,
    playerCount: 1,
    playerScores: [501],
    playerNames: ["Gracz 1"],
    activePlayerIndex: 0,
    activePlayerName: "Gracz 1",
    dartsLeftInTurn: 3,
    legStartScore: 501,
    gameOver: false,
    winnerName: nil,
    lastHitLabel: "",
    feedbackLabel: nil,
    aimGridX: DartBoardLayout.centerX,
    aimGridY: DartBoardLayout.centerY,
    throwPrimed: false,
    throwState: .idle,
    playZoneBand: .unknown,
    playZoneLevel: 0,
    playZoneHint: DartPlayZone.Band.unknown.hint,
    turnAnnouncement: nil,
    flightActive: false,
    flightGridX: DartBoardLayout.centerX,
    flightGridY: DartBoardLayout.centerY,
    flightProgress: 0,
    boardMarkers: [],
    startCountdown: 5,
    awaitingTurnStart: false
  )

  private var startCountdownRemaining: TimeInterval = 5
  private var lastCountdownTick = -1

  private var playZone = DartPlayZone()
  private var boardMarkers: [DartBoardMarker] = []
  private var activeFlight: DartFlightAnimation?
  private var pendingShot: ResolvedShot?

  private var aimX = 0.0
  private var aimY = 0.0
  private var aimNeutralX = 0.0
  private var aimNeutralY = 0.0
  private var throwNeutralTilt = 0.0
  private var gyroBaselineY = 0.0
  private var gyroBaselineX = 0.0
  private var gyroBaselineZ = 0.0
  private var centerX = 0.0
  private var centerY = 0.0

  private var shootHeld = false
  private var lastHitLabel = ""
  private var feedbackLabel: String?
  private var feedbackTimer = 0.0

  private var throwController = DartThrowController()
  private var arenaAnimTick: UInt = 0

  private let boardRadius = DartBoardLayout.boardRadius
  private var aimReach: Double { boardRadius * 0.92 }

  private var bullInnerR: Double { boardRadius * 5 / 45 }
  private var bullOuterR: Double { boardRadius * 10 / 45 }
  private var tripleInnerR: Double { boardRadius * 25 / 45 }
  private var tripleOuterR: Double { boardRadius * 30 / 45 }
  private var doubleInnerR: Double { boardRadius * 40 / 45 }
  private var doubleOuterR: Double { boardRadius }

  /// Wykonuje operację `start` w bieżącym kontekście gry/UI.
  func start(context: GameContext) {
    centerX = DartBoardLayout.centerX
    centerY = DartBoardLayout.centerY
    aimX = centerX
    aimY = centerY
    turnSwitchPending = false
    shootHeld = false
    feedbackLabel = nil
    feedbackTimer = 0
    turnAnnouncement = nil
    turnAnnouncementTimer = 0
    awaitingTurnStart = false
    turnGate.reset()
    boardMarkers = []
    activeFlight = nil
    pendingShot = nil
    startCountdownRemaining = 5
    lastCountdownTick = -1

    if let match = restoredMatch, match.playerCount == playerCount, match.canResume {
      playerScores = match.playerScores
      activePlayerIndex = min(match.activePlayerIndex, playerCount - 1)
      dartsLeftInTurn = match.dartsLeftInTurn
      turnStartScore = match.turnStartScore
      gameOver = match.gameOver
      winnerName = match.winnerName
      lastHitLabel = match.lastHitLabel
      playZone.reset()
      applyPlayerProfile(index: activePlayerIndex)
      turnGate.confirm(playerIndex: activePlayerIndex)
    } else {
      playerScores = DartPlayers.freshScores(count: playerCount)
      activePlayerIndex = 0
      dartsLeftInTurn = 3
      turnStartScore = activePlayerScore
      gameOver = false
      winnerName = nil
      lastHitLabel = ""
      playZone.reset()
      applyPlayerProfile(index: 0)
    }
    publishHUD()
  }

  /// Wykonuje operację `applyPlayerProfile` w bieżącym kontekście gry/UI.
  func applyPlayerProfile(index: Int) {
    guard let profile = DartPlayerProfileStore.profile(for: index) else {
      playZone.applySessionCalibration()
      throwController.applyDefaultCalibration()
      throwController.reset(tiltAxis: 0)
      return
    }
    aimNeutralX = profile.aimNeutralX
    aimNeutralY = profile.aimNeutralY
    throwNeutralTilt = profile.throwNeutralTilt
    gyroBaselineX = profile.gyroBaselineX
    gyroBaselineY = profile.gyroBaselineY
    gyroBaselineZ = profile.gyroBaselineZ
    playZone.applyProfile(profile)
    throwController.applyCalibration(
      pullDepth: profile.calibratedPullDepth,
      throwGyroPeak: profile.calibratedThrowGyroPeak
    )
    throwController.reset(tiltAxis: 0)
  }

  /// Wykonuje operację `calibratePlayZone` w bieżącym kontekście gry/UI.
  func calibratePlayZone(sensors: TrikiSensors) {
    playZone.calibrate(with: sensors)
    calibrateAimNeutral(sensors: sensors)
  }

  /// Wykonuje operację `calibrateAimNeutral` w bieżącym kontekście gry/UI.
  func calibrateAimNeutral(sensors: TrikiSensors) {
    let neutral = grip.calibrateNeutrals(from: sensors)
    aimNeutralX = neutral.aimX
    aimNeutralY = neutral.aimY
    throwNeutralTilt = neutral.throwTilt
    gyroBaselineX = sensors.gyroX
    gyroBaselineY = sensors.gyroY
    gyroBaselineZ = sensors.gyroZ
  }

  /// Wykonuje operację `update` w bieżącym kontekście gry/UI.
  func update(input: GameInput, deltaTime: TimeInterval) {
    arenaAnimTick &+= 1

    guard !gameOver else {
      publishHUD()
      return
    }

    if startCountdownRemaining > 0 {
      let tick = Int(ceil(startCountdownRemaining))
      if tick != lastCountdownTick, (1...5).contains(tick) {
        QuizSFX.menuFocus()
        lastCountdownTick = tick
      }
      startCountdownRemaining = max(0, startCountdownRemaining - deltaTime)
      if startCountdownRemaining == 0 {
        QuizSFX.roundStart()
        lastCountdownTick = -1
        if playerCount > 1 {
          beginAwaitingTurnStart()
        }
      }
      publishHUD()
      return
    }

    if awaitingTurnStart {
      if input.trikiButtonPressed {
        confirmTurnStart()
      }
      playZone.update(sensors: input.sensors)
      let aimZoneGain = playZone.band == .good ? 1.0 : (playZone.band == .far ? 1.12 : 0.95)
      updateAim(input: input, zoneGain: aimZoneGain)
      publishHUD()
      return
    }

    if turnAnnouncementTimer > 0 {
      turnAnnouncementTimer = max(0, turnAnnouncementTimer - deltaTime)
      if turnAnnouncementTimer == 0 {
        turnAnnouncement = nil
      }
    }

    if feedbackTimer > 0 {
      feedbackTimer = max(0, feedbackTimer - deltaTime)
      if feedbackTimer == 0 {
        feedbackLabel = nil
        if turnSwitchPending {
          turnSwitchPending = false
          advanceTurn()
        }
      }
    }

    if var flight = activeFlight {
      flight.advance(deltaTime: deltaTime)
      activeFlight = flight
      if flight.isFinished, let shot = pendingShot {
        completeFlight(shot: shot)
        activeFlight = nil
        pendingShot = nil
      }
      publishHUD()
      return
    }

    playZone.update(sensors: input.sensors)
    let zoneFactor = playZone.distanceFactor
    let aimZoneGain = playZone.band == .good ? 1.0 : (playZone.band == .far ? 1.12 : 0.95)

    if feedbackTimer <= 0, activeFlight == nil {
      let tiltAxis = grip.throwTiltAxis(from: input.sensors, neutral: throwNeutralTilt)
      let throwState = throwController.state
      let adaptGyroBaseline = throwState == .idle || throwState == .throwing
      let gyroForward = grip.throwGyroImpulse(
        from: input.sensors,
        baselineX: &gyroBaselineX,
        baselineY: &gyroBaselineY,
        baselineZ: &gyroBaselineZ,
        adaptBaseline: adaptGyroBaseline
      )
      if let power = throwController.update(
        tiltAxis: tiltAxis,
        gyroForward: gyroForward,
        deltaTime: deltaTime,
        distanceFactor: zoneFactor
      ) {
        if !shootHeld {
          shoot(power: power)
        }
        shootHeld = true
      } else {
        shootHeld = false
      }
    } else {
      shootHeld = false
    }

    if activeFlight == nil {
      updateAim(input: input, zoneGain: aimZoneGain)
    }

    publishHUD()
  }

  private func advanceTurn() {
    boardMarkers = []
    ArcadeAudio.turnChange()
    if playerCount > 1 {
      activePlayerIndex = (activePlayerIndex + 1) % playerCount
      applyPlayerProfile(index: activePlayerIndex)
      beginAwaitingTurnStart()
    }
    turnStartScore = activePlayerScore
    dartsLeftInTurn = 3
    throwController.reset(tiltAxis: 0)
  }

  private func beginAwaitingTurnStart() {
    awaitingTurnStart = true
    turnAnnouncement = activeName()
    turnAnnouncementTimer = 0
    throwController.reset(tiltAxis: 0)
  }

  private func confirmTurnStart() {
    turnGate.confirm(playerIndex: activePlayerIndex)
    awaitingTurnStart = false
    turnAnnouncement = nil
    turnAnnouncementTimer = 0
    throwController.reset(tiltAxis: 0)
    QuizSFX.menuConfirm()
  }

  private var activePlayerScore: Int {
    guard playerScores.indices.contains(activePlayerIndex) else { return 0 }
    return playerScores[activePlayerIndex]
  }

  private func addScore(_ points: Int) {
    let hit = max(0, points)
    let candidate = activePlayerScore - hit
    let validCheckout = candidate == 0 && isCheckoutDart
    let bust = candidate < 0 || candidate == 1 || (candidate == 0 && !validCheckout)

    if bust {
      setActiveScore(turnStartScore)
      lastHitLabel = "BUST"
      feedbackLabel = "BUST"
      ArcadeAudio.dartBust()
      feedbackTimer = 1.1
      turnSwitchPending = true
      return
    }

    setActiveScore(candidate)
    if candidate == 0 {
      gameOver = true
      winnerName = activeName()
      lastHitLabel = "\(activeName()) WINS"
      feedbackLabel = "WIN"
      feedbackTimer = 2.2
      ArcadeAudio.dartWin()
      return
    }

    dartsLeftInTurn = max(0, dartsLeftInTurn - 1)
    if dartsLeftInTurn == 0 {
      turnSwitchPending = true
    }
  }

  private var isCheckoutDart = false

  private func setActiveScore(_ value: Int) {
    guard playerScores.indices.contains(activePlayerIndex) else { return }
    playerScores[activePlayerIndex] = value
  }

  private func activeName() -> String {
    guard playerNames.indices.contains(activePlayerIndex) else {
      return DartPlayers.defaultName(index: activePlayerIndex)
    }
    let name = playerNames[activePlayerIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? DartPlayers.defaultName(index: activePlayerIndex) : name
  }

  private func updateAim(input: GameInput, zoneGain: Double) {
    let reach = aimReach
    let aimSlow = throwController.isAimSlowed
    let aimGain = (aimSlow ? 0.38 : 0.88) * zoneGain
    let follow = aimSlow ? 0.08 : 0.12

    let aim = grip.aimDelta(
      from: input,
      sensors: input.sensors,
      neutralX: aimNeutralX,
      neutralY: aimNeutralY
    )

    let targetX = centerX + min(reach, max(-reach, aim.x * reach * aimGain))
    let targetY = centerY + min(reach, max(-reach, aim.y * reach * aimGain))

    aimX = aimX * (1 - follow) + targetX * follow
    aimY = aimY * (1 - follow) + targetY * follow
  }

  private func publishHUD() {
    currentHUD = HUD(
      score: activePlayerScore,
      playerCount: playerCount,
      playerScores: playerScores,
      playerNames: playerNames,
      activePlayerIndex: activePlayerIndex,
      activePlayerName: activeName(),
      dartsLeftInTurn: dartsLeftInTurn,
      legStartScore: turnStartScore,
      gameOver: gameOver,
      winnerName: winnerName,
      lastHitLabel: lastHitLabel,
      feedbackLabel: feedbackLabel,
      aimGridX: aimX,
      aimGridY: aimY,
      throwPrimed: throwController.isPrimed && feedbackTimer <= 0,
      throwState: feedbackTimer > 0 ? .idle : throwController.state,
      playZoneBand: playZone.band,
      playZoneLevel: playZone.level,
      playZoneHint: playZone.band.hint,
      turnAnnouncement: turnAnnouncement,
      flightActive: activeFlight != nil,
      flightGridX: flightPosition.x,
      flightGridY: flightPosition.y,
      flightProgress: activeFlight?.progress ?? 0,
      boardMarkers: boardMarkers,
      startCountdown: startCountdownRemaining > 0 ? max(1, Int(ceil(startCountdownRemaining))) : nil,
      awaitingTurnStart: awaitingTurnStart
    )
  }

  private var flightPosition: (x: Double, y: Double) {
    if let flight = activeFlight {
      return flight.currentPosition
    }
    return (aimX, aimY)
  }

  private func shoot(power: Double) {
    let shot = resolveShot(power: power)
    pendingShot = shot
    let launchY = centerY + boardRadius + 14
    activeFlight = DartFlightAnimation(
      fromX: centerX,
      fromY: launchY,
      toX: shot.hitX,
      toY: shot.hitY,
      duration: 0.42,
      elapsed: 0
    )
    ArcadeAudio.dartThrowWhoosh()
  }

  private func completeFlight(shot: ResolvedShot) {
    if shot.onBoard {
      boardMarkers.append(DartBoardMarker(gridX: shot.hitX, gridY: shot.hitY))
    }
    lastHitLabel = shot.label
    isCheckoutDart = shot.isDoubleHit
    addScore(shot.points)
    isCheckoutDart = false
    if gameOver || feedbackLabel == "BUST" { return }
    if shot.points > 0 {
      feedbackLabel = "-\(shot.points)"
      ArcadeAudio.dartHit(points: shot.points)
    } else {
      feedbackLabel = "MISS"
      ArcadeAudio.dartHit(points: 0)
    }
    feedbackTimer = 1.45
  }

  private func resolveShot(power: Double) -> ResolvedShot {
    let spread = max(0.6, 3.4 - power * 0.14)
    let hitX = aimX + Double.random(in: -spread ... spread)
    let hitY = aimY + Double.random(in: -spread ... spread)
    let dx = hitX - centerX
    let dy = hitY - centerY
    let distance = sqrt(dx * dx + dy * dy)

    var points = 0
    var isDoubleHit = false
    var label = "MISS"
    if distance < bullInnerR {
      points = 50
      label = "BULL 50"
      isDoubleHit = true
    } else if distance < bullOuterR {
      points = 25
      label = "BULL 25"
    } else if distance <= boardRadius {
      let sector = DartBoardLayout.sectorIndex(dx: dx, dy: dy)
      let segmentValue = DartBoardLayout.segmentValues[sector]
      points = segmentValue
      if distance >= tripleInnerR, distance < tripleOuterR {
        points *= 3
        label = "T\(segmentValue)×3"
      } else if distance >= doubleInnerR, distance < doubleOuterR {
        points *= 2
        label = "D\(segmentValue)×2"
        isDoubleHit = true
      } else {
        label = "\(segmentValue)"
      }
    }
    let onBoard = distance <= boardRadius
    return ResolvedShot(
      hitX: hitX,
      hitY: hitY,
      points: points,
      label: label,
      isDoubleHit: isDoubleHit,
      onBoard: onBoard
    )
  }

  /// Wykonuje operację `render` w bieżącym kontekście gry/UI.
  func render(context: GameContext) {
    DartArenaScene.render(
      context: context,
      boardCenterX: centerX,
      boardCenterY: centerY,
      boardRadius: boardRadius,
      animTick: arenaAnimTick
    )
    drawBoard(context: context)
    DartBoardLayout.drawSegmentNumbers(
      context: context,
      centerX: centerX,
      centerY: centerY,
      boardRadius: boardRadius
    )
    drawStartCountdown(context: context)
    drawBoardMarkers(context: context)
    if let flight = activeFlight {
      let pos = flight.currentPosition
      drawDartTip(context: context, x: pos.x, y: pos.y, color: .white)
    }
  }

  private func drawStartCountdown(context: GameContext) {
    guard startCountdownRemaining > 0 else { return }
    let value = max(1, Int(ceil(startCountdownRemaining)))
    let label = "\(value)"
    let tx = Int(centerX.rounded()) - (label.count > 1 ? 8 : 4)
    let ty = Int(centerY.rounded()) - 6
    context.text(label, x: tx, y: ty, color: .yellow)
  }

  private func drawBoardMarkers(context: GameContext) {
    for marker in boardMarkers {
      drawDartTip(context: context, x: marker.gridX, y: marker.gridY, color: .yellow)
    }
  }

  private func drawDartTip(context: GameContext, x: Double, y: Double, color: PixelColor) {
    let px = Int(x.rounded())
    let py = Int(y.rounded())
    for ox in -1...1 {
      for oy in -1...1 {
        let gx = px + ox
        let gy = py + oy
        guard gx >= 0, gx < GameContext.width, gy >= GameContext.pixelTopInset, gy < GameContext.height else { continue }
        context.rect(x: gx, y: gy, width: 1, height: 1, color: color)
      }
    }
  }

  private func drawBoard(context: GameContext) {
    let cx = Int(centerX.rounded())
    let cy = Int(centerY.rounded())
    let rMax = Int(boardRadius.rounded(.up))

    for py in (cy - rMax)...(cy + rMax) {
      guard py >= GameContext.pixelTopInset, py < GameContext.height else { continue }
      for px in (cx - rMax)...(cx + rMax) {
        guard px >= 0, px < GameContext.width else { continue }
        let dx = Double(px - cx)
        let dy = Double(py - cy)
        let dist = sqrt(dx * dx + dy * dy)
        guard dist <= boardRadius else { continue }

        let color = boardPixelColor(dx: dx, dy: dy, distance: dist)
        context.rect(x: px, y: py, width: 1, height: 1, color: color)
      }
    }
  }

  private func boardPixelColor(dx: Double, dy: Double, distance: Double) -> PixelColor {
    if distance < bullInnerR { return .red }
    if distance < bullOuterR { return .green }
    if distance >= tripleInnerR, distance < tripleOuterR { return .red }
    if distance >= doubleInnerR, distance < doubleOuterR { return .green }

    let sector = DartBoardLayout.sectorIndex(dx: dx, dy: dy)
    return sector.isMultiple(of: 2) ? .white : .darkGray
  }
}
