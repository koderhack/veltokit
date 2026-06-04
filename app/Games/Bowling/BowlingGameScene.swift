import Foundation
import SceneKit
import UIKit

/// Scena 3D kręgli — tor, kula, kręgle, kamera, światło.
final class BowlingGameScene: SCNScene {
  /// Opisuje enum `Phase` używany przez warstwę UI i logikę gry.
  enum Phase: Equatable {
    case aiming
    case rolling
    case settling
  }

  /// Opisuje struct `PinState` używany przez warstwę UI i logikę gry.
  struct PinState {
    let node: SCNNode
    let restPosition: SCNVector3
    var knocked = false
    /// Trafiony bezpośrednio przez kulkę (do punktacji).
    var hitByBall = false
  }

  /// Przechowuje wartość `ballNode` wykorzystywaną przez dany komponent.
  let ballNode = SCNNode()
  /// Przechowuje wartość `cameraNode` wykorzystywaną przez dany komponent.
  let cameraNode = SCNNode()
  /// Przechowuje wartość `physicsHandler` wykorzystywaną przez dany komponent.
  let physicsHandler = BowlingPhysicsHandler()

  private(set) var phase: Phase = .aiming
  private(set) var pinStates: [PinState] = []
  private var cameraShake: Float = 0
  private var baseCameraOffset = SCNVector3(0, 1.35, 2.4)
  /// Stały kąt nachylenia kamery w dół (bez look-at — unika flipów).
  private let cameraPitch: Float = -0.24
  private var cameraFollowX: Float = 0
  private var rollElapsed: TimeInterval = 0
  private var stoppedFor: TimeInterval = 0
  private var peakBallSpeed: Float = 0
  private var throwStartZ: Float = 0
  private var pinsHiddenThisThrow = 0
  /// Kierunek hooka wzdłuż osi X (− lewo, + prawo).
  private var throwHookBias: Float = 0
  /// 0 = prosty rzut, 1 = mocno „zły” release.
  private var throwBadness: Float = 0
  private var throwSpinY: Float = 0

  /// Minimalny dystans kuli zanim zaliczymy wynik rzutu.
  private let minTravelBeforeScore: Float = 3.0

  private let laneLength: Float = 18
  private let laneWidth: Float = 1.05
  private let ballRadius: Float = 0.18
  private let pinSpacing: Float = 0.30
  private let pinHeight: Float = 0.38
  private let pinColliderRadius: Float = 0.064
  private let pinsZ: Float = -7.2
  private let ballStartZ: Float = 7.2
  private let lateralRange: Float = 0.46
  /// Wysokość środka kuli nad podłogą toru — musi trafiać w środek kręgli.
  private var ballLaneY: Float { laneSurfaceY + ballRadius + 0.015 }
  /// Górna powierzchnia toru (pozycja Y kręgli).
  private let laneSurfaceY: Float = 0.04

  override init() {
    super.init()
    buildEnvironment()
    buildLane()
    buildBall()
    buildPins()
    buildCameraAndLights()
    physicsHandler.configureWorld(physicsWorld)
    physicsHandler.onCollision = { [weak self] in
      DispatchQueue.main.async {
        self?.triggerCameraShake()
        ArcadeAudio.bowlingHit()
      }
    }
    physicsHandler.onPinContact = { [weak self] pinNode in
      self?.handleBallPinContact(pinNode)
    }
    setPinsFrozen(true)
    resetBall()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func buildEnvironment() {
    buildPixelBackdrop()

    let floor = SCNNode(geometry: SCNBox(width: 12, height: 0.08, length: 28, chamferRadius: 0))
    floor.geometry?.firstMaterial = BowlingPixelArt.floorMaterial()
    floor.position = SCNVector3(0, -0.04, 0)
    rootNode.addChildNode(floor)

    let backWall = SCNNode(geometry: SCNBox(width: 12, height: 4, length: 0.2, chamferRadius: 0))
    backWall.geometry?.firstMaterial = BowlingPixelArt.wallMaterial()
    backWall.position = SCNVector3(0, 2, pinsZ - 1.2)
    backWall.physicsBody = BowlingPhysicsHandler.makeStaticBody(category: .wall)
    rootNode.addChildNode(backWall)

    let sideMaterial = BowlingPixelArt.wallMaterial()
    for xSign: Float in [-1, 1] {
      let gutter = SCNNode(geometry: SCNBox(width: 0.5, height: 0.06, length: CGFloat(laneLength), chamferRadius: 0))
      gutter.geometry?.firstMaterial = sideMaterial
      gutter.position = SCNVector3(xSign * (laneWidth / 2 + 0.35), laneSurfaceY - 0.05, 0)
      gutter.physicsBody = BowlingPhysicsHandler.makeStaticBody(
        category: .gutter,
        friction: 0.2,
        collisionMask: BowlingPhysicsHandler.ballCategory
      )
      rootNode.addChildNode(gutter)

      let crowd = SCNNode(geometry: SCNPlane(width: 5, height: 3.5))
      crowd.geometry?.firstMaterial = BowlingPixelArt.crowdMaterial()
      crowd.position = SCNVector3(xSign * 3.2, 1.8, -1.5)
      crowd.eulerAngles = SCNVector3(0, xSign * 0.55, 0)
      rootNode.addChildNode(crowd)
    }
  }

  private func buildPixelBackdrop() {
    let sky = SCNNode(geometry: SCNPlane(width: 28, height: 8))
    sky.geometry?.firstMaterial = BowlingPixelArt.skyMaterial()
    sky.position = SCNVector3(0, 3.2, pinsZ - 2.5)
    rootNode.addChildNode(sky)

    for xSign: Float in [-1, 1] {
      let neon = SCNNode(geometry: SCNBox(width: 0.08, height: 0.08, length: 14, chamferRadius: 0))
      let neonMat = SCNMaterial()
      neonMat.diffuse.contents = xSign < 0 ? UIColor(red: 1, green: 0.2, blue: 0.7, alpha: 1) : UIColor(red: 0.2, green: 0.9, blue: 1, alpha: 1)
      neonMat.emission.contents = neonMat.diffuse.contents
      neonMat.lightingModel = .constant
      neon.geometry?.materials = [neonMat]
      neon.position = SCNVector3(xSign * 0.62, 0.12, 0)
      rootNode.addChildNode(neon)
    }
  }

  private func buildLane() {
    let lane = SCNNode(geometry: SCNBox(
      width: CGFloat(laneWidth),
      height: 0.04,
      length: CGFloat(laneLength),
      chamferRadius: 0.01
    ))
    lane.geometry?.firstMaterial = BowlingPixelArt.laneMaterial()
    lane.position = SCNVector3(0, laneSurfaceY - 0.02, 0)
    lane.physicsBody = BowlingPhysicsHandler.makeStaticBody(
      category: .lane,
      friction: 0.28,
      restitution: 0.02
    )
    rootNode.addChildNode(lane)

    buildLaneBumpers()
  }

  private func buildLaneBumpers() {
    let bumperMaterial = BowlingPixelArt.wallMaterial()
    for xSign: Float in [-1, 1] {
      let bumper = SCNNode(geometry: SCNBox(
        width: 0.06,
        height: 0.22,
        length: CGFloat(laneLength),
        chamferRadius: 0
      ))
      bumper.geometry?.firstMaterial = bumperMaterial
      bumper.position = SCNVector3(xSign * (laneWidth / 2 + 0.03), laneSurfaceY + 0.11, 0)
      bumper.physicsBody = BowlingPhysicsHandler.makeStaticBody(
        category: .bumper,
        friction: 0.15,
        restitution: 0.35
      )
      rootNode.addChildNode(bumper)
    }
  }

  private func buildBall() {
    let sphere = SCNSphere(radius: CGFloat(ballRadius))
    sphere.segmentCount = 8
    sphere.materials = [BowlingPixelArt.ballMaterial()]

    ballNode.geometry = sphere
    ballNode.physicsBody = BowlingPhysicsHandler.makeBallBody(radius: CGFloat(ballRadius))
    ballNode.physicsBody?.isAffectedByGravity = false
    rootNode.addChildNode(ballNode)
  }

  private func pinLayoutPositions() -> [SCNVector3] {
    let rows: [[Float]] = [
      [0],
      [-0.5, 0.5],
      [-1, 0, 1],
      [-1.5, -0.5, 0.5, 1.5],
    ]
    var positions: [SCNVector3] = []
    for (row, xs) in rows.enumerated() {
      let z = pinsZ + Float(row) * pinSpacing * 0.86
      for xScale in xs {
        positions.append(SCNVector3(xScale * pinSpacing, laneSurfaceY, z))
      }
    }
    return positions
  }

  private func buildPins() {
    pinStates = pinLayoutPositions().map { pos in
      let pin = makePinNode()
      pin.position = pos
      rootNode.addChildNode(pin)
      return PinState(node: pin, restPosition: pos)
    }
    setPinsFrozen(phase == .aiming)
  }

  private func makePinNode() -> SCNNode {
    let pin = SCNNode()
    let h = CGFloat(pinHeight)
    let baseR: CGFloat = 0.058
    let topR: CGFloat = 0.024
    let pinMat = BowlingPixelArt.pinBodyMaterial()

    let body = SCNCone(topRadius: topR, bottomRadius: baseR, height: h * 0.80)
    body.radialSegmentCount = 12
    body.materials = [pinMat]
    let bodyNode = SCNNode(geometry: body)
    bodyNode.position = SCNVector3(0, Float(h * 0.40), 0)
    pin.addChildNode(bodyNode)

    let neck = SCNCylinder(radius: topR * 1.15, height: h * 0.10)
    neck.radialSegmentCount = 10
    neck.materials = [pinMat]
    let neckNode = SCNNode(geometry: neck)
    neckNode.position = SCNVector3(0, Float(h * 0.87), 0)
    pin.addChildNode(neckNode)

    let head = SCNSphere(radius: topR * 1.45)
    head.segmentCount = 10
    head.materials = [pinMat]
    let headNode = SCNNode(geometry: head)
    headNode.position = SCNVector3(0, Float(h * 0.98), 0)
    pin.addChildNode(headNode)

    // Kolizja: cylinder od podstawy kręgla w górę (bez widocznej geometrii w scenie).
    let colliderH = CGFloat(pinHeight * 0.94)
    let colliderR = CGFloat(pinColliderRadius)
    let cyl = SCNCylinder(radius: colliderR, height: colliderH)
    let offset = SCNMatrix4MakeTranslation(0, Float(colliderH / 2), 0)
    let shape = SCNPhysicsShape(
      shapes: [SCNPhysicsShape(geometry: cyl, options: nil)],
      transforms: [NSValue(scnMatrix4: offset)]
    )
    let physics = BowlingPhysicsHandler.makePinBody(shape: shape)
    physics.centerOfMassOffset = SCNVector3(0, Float(colliderH * 0.42), 0)
    pin.physicsBody = physics

    return pin
  }

  private func buildCameraAndLights() {
    cameraNode.camera = SCNCamera()
    cameraNode.camera?.fieldOfView = 58
    cameraNode.camera?.zFar = 120
    cameraNode.eulerAngles = SCNVector3(cameraPitch, 0, 0)
    rootNode.addChildNode(cameraNode)

    let ambient = SCNNode()
    ambient.light = SCNLight()
    ambient.light?.type = .ambient
    ambient.light?.color = UIColor(white: 0.35, alpha: 1)
    rootNode.addChildNode(ambient)

    let key = SCNNode()
    key.light = SCNLight()
    key.light?.type = .directional
    key.light?.color = UIColor(white: 0.95, alpha: 1)
    key.light?.castsShadow = true
    key.eulerAngles = SCNVector3(-0.85, 0.35, 0)
    rootNode.addChildNode(key)

    let fill = SCNNode()
    fill.light = SCNLight()
    fill.light?.type = .directional
    fill.light?.color = UIColor(red: 0.55, green: 0.65, blue: 0.85, alpha: 1)
    fill.eulerAngles = SCNVector3(-0.4, -0.6, 0)
    rootNode.addChildNode(fill)
  }

  private var lastAimBallX: Float = .nan

  /// Wykonuje operację `setAiming` w bieżącym kontekście gry/UI.
  func setAiming(lateralPosX: Double) {
    guard phase == .aiming else { return }
    placeBall(lateralPosX: lateralPosX, snapCamera: false)
  }

  private func placeBall(lateralPosX: Double, snapCamera: Bool = true) {
    let x = Float(lateralPosX.clamped(to: -1...1)) * lateralRange
    let moved = lastAimBallX.isNaN || abs(x - lastAimBallX) > 0.0015
    ballNode.position = SCNVector3(x, ballLaneY, ballStartZ)
    ballNode.eulerAngles = SCNVector3Zero
    guard let body = ballNode.physicsBody else { return }
    body.type = .kinematic
    body.clearAllForces()
    body.velocity = SCNVector3Zero
    body.angularVelocity = SCNVector4Zero
    body.resetTransform()
    lastAimBallX = x
    if moved || snapCamera {
      updateCamera(toBall: ballNode.position, immediate: snapCamera)
    }
  }

  /// Wykonuje operację `throwBall` w bieżącym kontekście gry/UI.
  func throwBall(
    power: Double,
    lateralPosX: Double,
    releaseSpin: Double = 0.7,
    releaseTiltVelocity: Double = 0
  ) {
    guard phase == .aiming else { return }
    phase = .rolling
    rollElapsed = 0
    stoppedFor = 0
    peakBallSpeed = 0
    pinsHiddenThisThrow = 0

    placeBall(lateralPosX: lateralPosX)
    throwStartZ = ballNode.position.z
    setPinsFrozen(false)

    guard let body = ballNode.physicsBody else { return }
    body.type = .dynamic
    body.isAffectedByGravity = false
    body.clearAllForces()
    body.velocity = SCNVector3Zero
    body.angularVelocity = SCNVector4Zero
    ballNode.position.y = ballLaneY
    body.resetTransform()

    let forceScale = Float(power.clamped(to: 4...20))
    let lateral = Float(lateralPosX.clamped(to: -1...1))
    let speed = forceScale * 4.0
    let spinMetric = Float(releaseSpin.clamped(to: 0.3...1.8))
    let tiltMetric = Float(abs(releaseTiltVelocity).clamped(to: 0...0.12))

    // Zły rzut: daleko od środka, duży spin boczny vs kierunek, nerwowy release tilt.
    let offCenter = abs(lateral)
    let spinMismatch = offCenter * spinMetric * 0.35
    throwBadness = min(1, offCenter * 0.72 + spinMismatch * 0.55 + tiltMetric * 4.2)

    // Kąt wyjścia z dłoni — im gorszy rzut, tym bardziej „skosem”.
    let releaseAngle = lateral * (0.05 + throwBadness * 0.16)
    let vx = sin(releaseAngle) * speed * (0.06 + throwBadness * 0.08)
    let vz = -cos(releaseAngle) * speed

    // Hook: spin boczny + dryf od linii (jak olej na torze).
    throwHookBias = lateral * (0.28 + throwBadness * 0.62)
    throwSpinY = -lateral * speed * (0.038 + spinMetric * 0.022 + throwBadness * 0.018)

    body.velocity = SCNVector3(vx, 0, vz)
    body.angularVelocity = SCNVector4(
      throwSpinY * 0.12 * throwBadness,
      throwSpinY,
      lateral * throwBadness * 0.1,
      1
    )

    ArcadeAudio.bowlingThrow()
  }

  /// Wykonuje operację `update` w bieżącym kontekście gry/UI.
  func update(deltaTime: TimeInterval) {
    if phase == .rolling || phase == .settling {
      rollElapsed += deltaTime
      peakBallSpeed = max(peakBallSpeed, currentBallSpeed())
      lockBallOnLane()
      applyBallHook(deltaTime: Float(deltaTime))
      clampBallSpeed()
      constrainBallToLane()
      resolveBallPinHits()
      if rollElapsed >= 0.35, ballTravelDistance >= minTravelBeforeScore {
        processKnockedPinsDuringRoll()
      }
      updateCamera(toBall: ballNode.presentation.position, immediate: false)
      decayCameraShake(deltaTime: deltaTime)
      if isBallStopped() {
        stoppedFor += deltaTime
        if phase == .rolling { phase = .settling }
      } else {
        stoppedFor = 0
      }
    } else {
      updateCamera(toBall: ballNode.position, immediate: false)
    }
  }

  private var ballTravelDistance: Float {
    throwStartZ - ballNode.presentation.position.z
  }

  private var ballInPinZone: Bool {
    ballNode.presentation.position.z < pinsZ + 3.0
  }

  private func lockBallOnLane() {
    guard let body = ballNode.physicsBody else { return }
    var v = body.velocity
    body.velocity = SCNVector3(v.x, 0, v.z)
    let y = ballNode.presentation.position.y
    if abs(y - ballLaneY) > 0.025 {
      let saved = body.velocity
      ballNode.position.y = ballLaneY
      body.velocity = saved
    }
  }

  /// Hook / zakręt — rośnie w połowie toru; mocniejszy przy złym release.
  private func applyBallHook(deltaTime dt: Float) {
    guard let body = ballNode.physicsBody else { return }
    guard dt > 0 else { return }

    let v = body.velocity
    let forward = max(0.35, -v.z)
    let travelT = ballTravelDistance / max(1, laneLength * 0.92)
    // „Olej” na początku — hook narasta w drugiej połowie toru.
    let hookPhase = smoothstep(0.15, 0.82, travelT)

    let spinY = body.angularVelocity.y
    // Efekt Magnusa — spin boczny przesuwa kulkę w bok.
    let magnus = spinY * forward * hookPhase * 0.024 * dt
    // Tarcie toru — dryf w stronę hook bias (jak reakcja na pasie oleju).
    let frictionHook = throwHookBias * forward * hookPhase * hookPhase * 0.028 * dt
    // Zły release — dodatkowe „pływanie” toru.
    let wobble = throwBadness * sin(Float(rollElapsed) * 4.2 + throwSpinY) * forward * 0.004 * dt

    var vx = v.x + magnus + frictionHook + wobble

    // Prosty rzut ze środka — lekka stabilizacja toru.
    if throwBadness < 0.22 {
      vx *= (1 - 0.06 * dt)
    }

    body.velocity = SCNVector3(vx, 0, v.z)

    // Utrzymaj obrót toczenia + spin hooka.
    let rollSpin = -vx / max(0.08, ballRadius)
    let spinDamp = 1 - min(0.14, 0.06 * dt)
    body.angularVelocity = SCNVector4(
      body.angularVelocity.x * spinDamp,
      (spinY * spinDamp) + rollSpin * 0.08,
      body.angularVelocity.z * spinDamp,
      1
    )
  }

  private func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
    guard edge1 > edge0 else { return x >= edge1 ? 1 : 0 }
    let t = min(1, max(0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
  }

  private func clampBallSpeed(maxSpeed: Float = 14) {
    guard let body = ballNode.physicsBody else { return }
    let v = body.velocity
    let speed = sqrt(v.x * v.x + v.z * v.z)
    guard speed > maxSpeed else { return }
    let scale = maxSpeed / speed
    body.velocity = SCNVector3(v.x * scale, 0, v.z * scale)
  }

  /// Pewne trafienie — jeden najbliższy kręgel na klatkę (bez masowego przewracania).
  private func resolveBallPinHits() {
    guard phase == .rolling || phase == .settling else { return }
    guard ballTravelDistance >= 2.0 || ballInPinZone else { return }
    guard let ballBody = ballNode.physicsBody else { return }

    let ballPos = ballNode.presentation.position
    let hitDist = ballRadius + pinColliderRadius + 0.008
    let pinCenterY = laneSurfaceY + pinHeight * 0.46

    var closestIndex: Int?
    var closestDist: Float = .greatestFiniteMagnitude

    for index in pinStates.indices where !pinStates[index].knocked {
      let pinPos = pinStates[index].node.presentation.position
      let dx = ballPos.x - pinPos.x
      let dz = ballPos.z - pinPos.z
      let horiz = sqrt(dx * dx + dz * dz)
      let vert = abs(ballPos.y - pinCenterY)
      guard vert < pinHeight * 0.5 else { continue }
      guard horiz < hitDist, horiz < closestDist else { continue }
      closestIndex = index
      closestDist = horiz
    }

    guard let index = closestIndex else { return }
    let pinPos = pinStates[index].node.presentation.position
    let dx = ballPos.x - pinPos.x
    let dz = ballPos.z - pinPos.z
    let horiz = max(closestDist, 0.001)

    knockPin(at: index, fromBall: true)

    let nx = dx / horiz
    let nz = dz / horiz
    let penetration = hitDist - horiz
    ballNode.position = SCNVector3(
      ballPos.x + nx * penetration * 0.3,
      ballLaneY,
      ballPos.z + nz * penetration * 0.3
    )
    ballBody.resetTransform()

    let v = ballBody.velocity
    let forward = max(1.8, -v.z)
    ballBody.velocity = SCNVector3(v.x * 0.22, 0, -forward * 0.95)
  }

  /// Wykonuje operację `handleBallPinContact` w bieżącym kontekście gry/UI.
  func handleBallPinContact(_ pinNode: SCNNode) {
    guard phase == .rolling || phase == .settling else { return }
    guard rollElapsed >= 0.08 else { return }
    guard ballTravelDistance >= minTravelBeforeScore || ballInPinZone else { return }
    guard let index = pinIndex(for: pinNode) else { return }
    knockPin(at: index, fromBall: true)
  }

  private func pinIndex(for node: SCNNode) -> Int? {
    pinStates.firstIndex { state in
      !state.knocked && (state.node === node || nodeHasAncestor(node, ancestor: state.node) || nodeHasAncestor(state.node, ancestor: node))
    }
  }

  private func nodeHasAncestor(_ node: SCNNode, ancestor: SCNNode) -> Bool {
    var current: SCNNode? = node
    while let currentNode = current {
      if currentNode === ancestor { return true }
      current = currentNode.parent
    }
    return false
  }

  /// Ukryj powalone kręgle i zakończ rzut, gdy kula zwolni po trafieniu.
  func shouldEndThrow() -> Bool {
    guard rollElapsed >= 0.65 else { return false }

    let slow = currentBallSpeed() < 0.42
    let stopped = isBallStopped()
    let ballZ = ballNode.presentation.position.z
    let pastPins = ballZ < pinsZ + 2.2
    let traveled = ballTravelDistance >= 1.5
    let knocked = pinsHiddenThisThrow

    if knocked > 0 {
      if rollElapsed >= 0.85, slow { return true }
      if pastPins, rollElapsed >= 1.0 { return true }
    }

    // Pudło / gutter — kula się zatrzymała albo minęła strefę kręgli.
    if traveled, rollElapsed >= 1.0, stopped, stoppedFor >= 0.2 { return true }
    if pastPins, rollElapsed >= 1.1, slow { return true }
    if rollElapsed >= 2.2, stopped { return true }

    return stoppedFor >= 0.45 && stopped && rollElapsed >= 1.4
  }

  /// Zaznacza kręgle przewrócone fizyką (również po zderzeniu z innym kręglem), żeby wynik = animacja.
  func processKnockedPinsDuringRoll() {
    guard phase == .rolling || phase == .settling else { return }
    for index in pinStates.indices where !pinStates[index].knocked {
      if isPinFallen(index) {
        knockPin(at: index, fromBall: false, applyImpulse: false)
      }
    }
  }

  /// Trafienie kuli — kręgel przewraca się fizycznie, zostaje w scenie do końca rzutu.
  private func knockPin(at index: Int, fromBall: Bool, applyImpulse: Bool = true) {
    guard pinStates.indices.contains(index), !pinStates[index].knocked else { return }
    pinStates[index].knocked = true
    if fromBall { pinStates[index].hitByBall = true }
    pinsHiddenThisThrow += 1

    let node = pinStates[index].node
    guard let body = node.physicsBody else { return }
    if body.type == .kinematic { body.type = .dynamic }

    guard applyImpulse else { return }

    let ballPos = ballNode.presentation.worldPosition
    let pinPos = node.presentation.worldPosition
    var dirX = pinPos.x - ballPos.x
    var dirZ = pinPos.z - ballPos.z
    let len = sqrt(dirX * dirX + dirZ * dirZ)
    if len > 0.001 {
      dirX /= len
      dirZ /= len
    } else {
      dirX = 0
      dirZ = 1
    }

    body.applyForce(SCNVector3(dirX * 1.1, 0.03, dirZ * 1.1), asImpulse: true)
    body.applyTorque(SCNVector4(dirZ * 1.2, 0, -dirX * 1.2, 1), asImpulse: true)
  }

  private func hidePin(at index: Int) {
    guard pinStates.indices.contains(index), !pinStates[index].knocked else { return }
    pinStates[index].knocked = true
    pinsHiddenThisThrow += 1
    let node = pinStates[index].node
    node.physicsBody = nil
    node.removeFromParentNode()
  }

  private func isPinFallen(_ index: Int) -> Bool {
    if pinStates[index].knocked { return true }
    guard rollElapsed >= 0.25 else { return false }
    guard ballTravelDistance >= minTravelBeforeScore || ballInPinZone else { return false }

    let root = pinStates[index].node
    let rest = pinStates[index].restPosition
    let world = root.presentation.worldPosition
    let dx = world.x - rest.x
    let dz = world.z - rest.z
    let horizontal = sqrt(dx * dx + dz * dz)

    let tiltX = abs(root.presentation.eulerAngles.x)
    let tiltZ = abs(root.presentation.eulerAngles.z)
    let tilted = tiltX > 0.52 || tiltZ > 0.52
    let fallen = world.y < rest.y - 0.015
    let pushed = horizontal > 0.14

    return fallen || (tilted && pushed)
  }

  private func constrainBallToLane() {
    guard let body = ballNode.physicsBody else { return }
    let pos = ballNode.presentation.position
    let halfLane = laneWidth / 2 - ballRadius - 0.04
    var v = body.velocity

    if pos.x < -halfLane {
      body.velocity = SCNVector3(abs(v.x) * 0.12, 0, v.z)
    } else if pos.x > halfLane {
      body.velocity = SCNVector3(-abs(v.x) * 0.12, 0, v.z)
    }

    if pos.z > ballStartZ + 0.25 {
      body.velocity = SCNVector3(v.x, 0, min(v.z, 0))
    }
    if pos.z < pinsZ - 3.2 {
      body.velocity = SCNVector3(v.x, 0, max(v.z, 0))
    }
  }

  /// Wykonuje operację `isReadyToScore` w bieżącym kontekście gry/UI.
  func isReadyToScore() -> Bool {
    guard rollElapsed >= 0.9 else { return false }
    guard peakBallSpeed > 0.25 else { return false }
    guard stoppedFor >= 0.35 else { return false }
    return isBallStopped()
  }

  private func currentBallSpeed() -> Float {
    guard let body = ballNode.physicsBody else { return 0 }
    let v = body.velocity
    return sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
  }

  /// Wykonuje operację `isBallStopped` w bieżącym kontekście gry/UI.
  func isBallStopped() -> Bool {
    currentBallSpeed() < 0.12
  }

  /// Wykonuje operację `countKnockedPins` w bieżącym kontekście gry/UI.
  func countKnockedPins() -> Int {
    pinStates.filter(\.knocked).count
  }

  /// Do punktacji — wszystkie kręgle powalone w tym rzucie (kula + reakcja łańcuchowa).
  func countScoredPins() -> Int {
    pinStates.filter(\.knocked).count
  }

  /// Wykonuje operację `resetBall` w bieżącym kontekście gry/UI.
  func resetBall() {
    phase = .aiming
    rollElapsed = 0
    stoppedFor = 0
    peakBallSpeed = 0
    pinsHiddenThisThrow = 0
    throwHookBias = 0
    throwBadness = 0
    throwSpinY = 0
    cameraFollowX = 0
    lastAimBallX = .nan
    ballNode.eulerAngles = SCNVector3Zero
    ballNode.position = SCNVector3(0, ballLaneY, ballStartZ)
    guard let body = ballNode.physicsBody else { return }
    body.type = .kinematic
    body.isAffectedByGravity = false
    body.clearAllForces()
    body.velocity = SCNVector3Zero
    body.angularVelocity = SCNVector4Zero
    body.resetTransform()
    setPinsFrozen(true)
    updateCamera(toBall: ballNode.position, immediate: true)
  }

  /// Wykonuje operację `resetAllPins` w bieżącym kontekście gry/UI.
  func resetAllPins() {
    for state in pinStates {
      state.node.removeFromParentNode()
    }
    pinStates.removeAll()
    buildPins()
  }

  /// Wykonuje operację `removeKnockedPins` w bieżącym kontekście gry/UI.
  func removeKnockedPins() {
    for index in pinStates.indices where pinStates[index].knocked {
      pinStates[index].node.removeFromParentNode()
    }
    pinStates.removeAll { $0.knocked }
  }

  /// Przed rzutem upewnij się, że na torze stoi właściwa liczba kręgli.
  func ensureStandingPins(_ expected: Int) {
    let standing = pinStates.filter { !$0.knocked && $0.node.parent != nil }
    if expected <= 0 { return }
    if standing.count == expected {
      setPinsFrozen(true)
      return
    }
    if expected == 10 {
      resetAllPins()
      return
    }
    // Odtwórz pełny rząd i usuń tyle z przodu, ile powinno brakować (awaryjnie).
    resetAllPins()
    let toKnock = max(0, 10 - expected)
    for index in 0..<toKnock where pinStates.indices.contains(index) {
      hidePin(at: index)
    }
    removeKnockedPins()
    setPinsFrozen(true)
  }

  /// Wykonuje operację `prepareSecondThrow` w bieżącym kontekście gry/UI.
  func prepareSecondThrow() {
    removeKnockedPins()
    resetBall()
  }

  /// Kręgle stoją nieruchomo do rzutu — bez drgań od solvera fizyki.
  func setPinsFrozen(_ frozen: Bool) {
    for state in pinStates where !state.knocked {
      guard let body = state.node.physicsBody else { continue }
      if frozen {
        body.type = .kinematic
        body.clearAllForces()
        body.velocity = SCNVector3Zero
        body.angularVelocity = SCNVector4Zero
        state.node.removeAllActions()
        state.node.opacity = 1
        state.node.position = state.restPosition
        state.node.eulerAngles = SCNVector3Zero
        body.resetTransform()
      } else if body.type == .kinematic {
        body.type = .dynamic
        body.velocity = SCNVector3Zero
        body.angularVelocity = SCNVector4Zero
        body.resetTransform()
      }
    }
  }

  private func updateCamera(toBall position: SCNVector3, immediate: Bool) {
    let t = Float(rollElapsed)
    let shakeX = cameraShake * sin(t * 38) * 0.035
    let shakeY = cameraShake * cos(t * 31) * 0.022

    let desiredFollowX = position.x * 0.32
    let maxCamX = laneWidth * 0.55
    let clampedFollowX = min(maxCamX, max(-maxCamX, desiredFollowX))

    if immediate {
      cameraFollowX = clampedFollowX
    } else {
      cameraFollowX = cameraFollowX + (clampedFollowX - cameraFollowX) * 0.10
    }

    let target = SCNVector3(
      cameraFollowX + shakeX,
      baseCameraOffset.y + shakeY,
      position.z + baseCameraOffset.z
    )
    if immediate {
      cameraNode.position = target
    } else {
      cameraNode.position = lerp(cameraNode.position, target, t: 0.10)
    }

    // Stała orientacja — patrz w dół toru; bez look(at), które gimbal-lockuje.
    cameraNode.eulerAngles = SCNVector3(cameraPitch, 0, 0)
  }

  private func triggerCameraShake() {
    cameraShake = min(1, cameraShake + 0.35)
  }

  private func decayCameraShake(deltaTime: TimeInterval) {
    cameraShake = max(0, cameraShake - Float(deltaTime) * 2.2)
  }
}

// MARK: - Pixel textures

/// Opisuje enum `BowlingPixelArt` używany przez warstwę UI i logikę gry.
enum BowlingPixelArt {
  static func laneMaterial() -> SCNMaterial {
    pixelMaterial(
      pattern: { x, y in
        let plank = (x / 4) % 2 == 0
        let grain = (x + y * 3) % 7 == 0
        if grain { return UIColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1) }
        return plank
          ? UIColor(red: 0.72, green: 0.48, blue: 0.26, alpha: 1)
          : UIColor(red: 0.58, green: 0.38, blue: 0.20, alpha: 1)
      },
      width: 32,
      height: 32
    )
  }

  static func floorMaterial() -> SCNMaterial {
    pixelMaterial(
      pattern: { x, y in
        let c = (x / 6 + y / 6) % 2 == 0
        return c
          ? UIColor(red: 0.10, green: 0.11, blue: 0.18, alpha: 1)
          : UIColor(red: 0.07, green: 0.08, blue: 0.14, alpha: 1)
      },
      width: 24,
      height: 24
    )
  }

  static func wallMaterial() -> SCNMaterial {
    pixelMaterial(
      pattern: { x, y in
        let brick = ((y / 4) % 2 == 0 ? x : x + 2) / 4 % 2 == 0
        return brick
          ? UIColor(red: 0.16, green: 0.18, blue: 0.28, alpha: 1)
          : UIColor(red: 0.11, green: 0.13, blue: 0.22, alpha: 1)
      },
      width: 28,
      height: 28
    )
  }

  static func crowdMaterial() -> SCNMaterial {
    pixelMaterial(
      pattern: { x, y in
        let palette: [UIColor] = [
          UIColor(red: 0.95, green: 0.25, blue: 0.55, alpha: 1),
          UIColor(red: 0.20, green: 0.85, blue: 0.95, alpha: 1),
          UIColor(red: 0.95, green: 0.85, blue: 0.20, alpha: 1),
          UIColor(red: 0.35, green: 0.95, blue: 0.45, alpha: 1),
          UIColor(red: 0.92, green: 0.92, blue: 0.95, alpha: 1),
        ]
        if y % 5 == 0 { return UIColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1) }
        let pick = (x * 3 + y * 7) % palette.count
        let head = (x % 6 == 0 || y % 4 == 0) && (x + y) % 3 != 0
        return head ? palette[pick] : UIColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1)
      },
      width: 48,
      height: 32
    )
  }

  static func skyMaterial() -> SCNMaterial {
    pixelMaterial(
      pattern: { x, y in
        let t = Double(y) / 31.0
        if t < 0.35 {
          return UIColor(red: 0.05, green: 0.06, blue: 0.14, alpha: 1)
        }
        if t < 0.55 {
          return UIColor(red: 0.10, green: 0.12, blue: 0.32, alpha: 1)
        }
        let star = (x * 13 + y * 17) % 23 == 0
        return star
          ? UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1)
          : UIColor(red: 0.06, green: 0.08, blue: 0.20, alpha: 1)
      },
      width: 64,
      height: 32
    )
  }

  static func pinBodyMaterial() -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = pixelImage(
      pattern: { x, y in
        // Biały kręgiel z czerwonym pasem (jak na prawdziwym torze).
        let redBand = y >= 9 && y <= 12
        if redBand { return UIColor(red: 0.82, green: 0.10, blue: 0.14, alpha: 1) }
        let shade = (x + y) % 4 == 0
        return shade
          ? UIColor(white: 0.94, alpha: 1)
          : UIColor(white: 0.99, alpha: 1)
      },
      width: 8,
      height: 20
    )
    m.diffuse.magnificationFilter = .nearest
    m.diffuse.minificationFilter = .nearest
    m.lightingModel = .lambert
    return m
  }

  static func pinMaterial() -> SCNMaterial {
    pinBodyMaterial()
  }

  static func ballMaterial() -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = pixelImage(
      pattern: { x, y in
        let dx = Double(x) - 3.5
        let dy = Double(y) - 3.5
        let dist = sqrt(dx * dx + dy * dy)
        if dist > 3.6 { return UIColor(red: 0.08, green: 0.25, blue: 0.65, alpha: 1) }
        let shine = (x + y) % 3 == 0 && dist < 2.2
        return shine
          ? UIColor(red: 0.45, green: 0.72, blue: 1.0, alpha: 1)
          : UIColor(red: 0.12, green: 0.42, blue: 0.92, alpha: 1)
      },
      width: 8,
      height: 8
    )
    m.diffuse.magnificationFilter = .nearest
    m.diffuse.minificationFilter = .nearest
    m.lightingModel = .lambert
    return m
  }

  private static func pixelMaterial(
    pattern: (_ x: Int, _ y: Int) -> UIColor,
    width: Int,
    height: Int
  ) -> SCNMaterial {
    let m = SCNMaterial()
    m.diffuse.contents = pixelImage(pattern: pattern, width: width, height: height)
    m.diffuse.magnificationFilter = .nearest
    m.diffuse.minificationFilter = .nearest
    m.lightingModel = .lambert
    m.isDoubleSided = false
    return m
  }

  private static func pixelImage(
    pattern: (_ x: Int, _ y: Int) -> UIColor,
    width: Int,
    height: Int
  ) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
    return renderer.image { ctx in
      for y in 0..<height {
        for x in 0..<width {
          pattern(x, y).setFill()
          ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
      }
    }
  }
}

private extension Comparable {
  /// Wykonuje operację `clamped` w bieżącym kontekście gry/UI.
  func clamped(to range: ClosedRange<Self>) -> Self {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

private func lerp(_ a: SCNVector3, _ b: SCNVector3, t: Float) -> SCNVector3 {
  SCNVector3(
    a.x + (b.x - a.x) * t,
    a.y + (b.y - a.y) * t,
    a.z + (b.z - a.z) * t
  )
}
