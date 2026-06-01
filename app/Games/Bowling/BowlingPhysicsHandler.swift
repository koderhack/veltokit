import Foundation
import SceneKit

/// Fizyka i kolizje — dźwięk uderzenia, camera shake.
final class BowlingPhysicsHandler: NSObject, SCNPhysicsContactDelegate {
  static let ballCategory: Int = 1 << 0
  static let pinCategory: Int = 1 << 1
  static let laneCategory: Int = 1 << 2
  static let gutterCategory: Int = 1 << 3
  static let wallCategory: Int = 1 << 4
  static let bumperCategory: Int = 1 << 5

  enum StaticCategory {
    case lane
    case gutter
    case wall
    case bumper
  }

  var onCollision: (() -> Void)?
  var onPinContact: ((SCNNode) -> Void)?

  private var lastCollisionAt: TimeInterval = 0
  private var lastPinContactAt: [ObjectIdentifier: TimeInterval] = [:]
  private let collisionCooldown: TimeInterval = 0.08

  func configureWorld(_ world: SCNPhysicsWorld) {
    world.gravity = SCNVector3(0, -9.8, 0)
    world.speed = 1.2
    world.contactDelegate = self
  }

  static func makeStaticBody(
    category: StaticCategory,
    friction: CGFloat = 0.9,
    restitution: CGFloat = 0.05,
    collisionMask: Int? = nil
  ) -> SCNPhysicsBody {
    let body = SCNPhysicsBody(type: .static, shape: nil)
    body.friction = friction
    body.restitution = restitution
    switch category {
    case .lane:
      body.categoryBitMask = laneCategory
      body.collisionBitMask = collisionMask ?? (ballCategory | pinCategory)
    case .gutter:
      body.categoryBitMask = gutterCategory
      body.collisionBitMask = collisionMask ?? ballCategory
    case .wall:
      body.categoryBitMask = wallCategory
      body.collisionBitMask = ballCategory
    case .bumper:
      body.categoryBitMask = bumperCategory
      body.collisionBitMask = ballCategory
    }
    return body
  }

  static func makeBallBody(radius: CGFloat) -> SCNPhysicsBody {
    let shape = SCNPhysicsShape(geometry: SCNSphere(radius: radius), options: nil)
    let body = SCNPhysicsBody(type: .dynamic, shape: shape)
    body.mass = 7.5
    body.friction = 0.22
    body.restitution = 0.08
    body.rollingFriction = 0.025
    body.damping = 0.05
    body.angularDamping = 0.10
    body.continuousCollisionDetectionThreshold = 0.5
    body.categoryBitMask = ballCategory
    body.collisionBitMask = laneCategory | bumperCategory | wallCategory | pinCategory
    body.contactTestBitMask = pinCategory
    return body
  }

  static func makePinBody(shape: SCNPhysicsShape) -> SCNPhysicsBody {
    let body = SCNPhysicsBody(type: .dynamic, shape: shape)
    body.mass = 1.53
    body.friction = 0.42
    body.restitution = 0.06
    body.rollingFriction = 0.22
    body.damping = 0.12
    body.angularDamping = 0.28
    body.allowsResting = true
    body.categoryBitMask = pinCategory
    body.collisionBitMask = ballCategory | pinCategory | laneCategory
    body.contactTestBitMask = ballCategory | pinCategory
    return body
  }

  static func makePinBody(radius: CGFloat, height: CGFloat) -> SCNPhysicsBody {
    let shape = SCNPhysicsShape(
      geometry: SCNCylinder(radius: radius, height: height),
      options: nil
    )
    let body = SCNPhysicsBody(type: .dynamic, shape: shape)
    body.mass = 0.85
    body.friction = 0.35
    body.restitution = 0.12
    body.rollingFriction = 0.15
    body.damping = 0.08
    body.angularDamping = 0.45
    body.allowsResting = true
    body.categoryBitMask = pinCategory
    body.collisionBitMask = ballCategory | pinCategory | laneCategory
    body.contactTestBitMask = ballCategory | pinCategory
    return body
  }

  func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
    let a = contact.nodeA.physicsBody?.categoryBitMask ?? 0
    let b = contact.nodeB.physicsBody?.categoryBitMask ?? 0
    let involvesBall = (a & Self.ballCategory) != 0 || (b & Self.ballCategory) != 0
    let involvesPin = (a & Self.pinCategory) != 0 || (b & Self.pinCategory) != 0
    guard involvesBall, involvesPin else { return }

    // Dodatkowy impuls na kręgle — pewniejsze przewracanie.
    let pinBody = (a & Self.pinCategory) != 0 ? contact.nodeA.physicsBody : contact.nodeB.physicsBody
    let ballBody = (a & Self.ballCategory) != 0 ? contact.nodeA.physicsBody : contact.nodeB.physicsBody
    if let pinBody, let ballBody {
      if pinBody.type == .kinematic { pinBody.type = .dynamic }
      let speed = sqrt(
        ballBody.velocity.x * ballBody.velocity.x
          + ballBody.velocity.z * ballBody.velocity.z
      )
      let push = max(0.6, speed * 0.15)
      let impulse = SCNVector3(
        ballBody.velocity.x * 0.08 + contact.contactNormal.x * push * 0.05,
        0.03,
        ballBody.velocity.z * 0.08 + contact.contactNormal.z * push * 0.05
      )
      pinBody.applyForce(impulse, asImpulse: true)
    }

    let pinNode = (a & Self.pinCategory) != 0 ? contact.nodeA : contact.nodeB
    let pinKey = ObjectIdentifier(pinNode)
    let now = ProcessInfo.processInfo.systemUptime
    if now - (lastPinContactAt[pinKey] ?? 0) >= collisionCooldown {
      lastPinContactAt[pinKey] = now
      let pinHandler = onPinContact
      DispatchQueue.main.async {
        pinHandler?(pinNode)
      }
    }

    guard now - lastCollisionAt >= collisionCooldown else { return }
    lastCollisionAt = now
    let handler = onCollision
    DispatchQueue.main.async {
      handler?()
    }
  }
}
