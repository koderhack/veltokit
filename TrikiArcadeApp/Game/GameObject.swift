import Foundation
import TrikiMotionKit

/// Minimalny wektor 2D do pozycji i ruchu.
struct Vec2: Equatable {
  var x: Double
  var y: Double

  static let zero = Vec2(x: 0, y: 0)

  static func + (lhs: Vec2, rhs: Vec2) -> Vec2 { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
  static func * (lhs: Vec2, rhs: Double) -> Vec2 { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
}

/// Minimalny odpowiednik "Node"/"GameObject" (inspiracja Godot).
/// Dev implementuje tylko `update` i `render`.
@MainActor
class GameObject: Identifiable {
  let id = UUID()

  var position: Vec2
  var isActive: Bool = true

  init(position: Vec2 = .zero) {
    self.position = position
  }

  func start(context: GameContext) {
    // opcjonalnie w subclass
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    // opcjonalnie w subclass
    // Dev używa input.rotation / input.moveX / input.moveY / input.shake / input.action
  }

  func render(context: GameContext) {
    // opcjonalnie w subclass
  }
}

/// Najprostsza "scena/świat" zarządzająca obiektami.
/// To jest celowo małe: bez fizyki, bez edytora, bez drzewa scen.
@MainActor
final class GameWorld {
  private(set) var objects: [GameObject] = []

  func add(_ object: GameObject) {
    objects.append(object)
  }

  func removeInactive() {
    objects.removeAll { !$0.isActive }
  }

  func start(context: GameContext) {
    for o in objects where o.isActive {
      o.start(context: context)
    }
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    for o in objects where o.isActive {
      o.update(input: input, deltaTime: deltaTime)
    }
    removeInactive()
  }

  func render(context: GameContext) {
    for o in objects where o.isActive {
      o.render(context: context)
    }
  }
}

/// Gotowy adapter: implementuje `Game` przez `GameWorld`.
/// Dev może zrobić własną grę jako: `final class MyGame: WorldGame { ... }`
@MainActor
class WorldGame: Game {
  let world = GameWorld()

  var name: String { "WorldGame" }
  var inputProfile: GameInputProfile { .default }

  func start(context: GameContext) {
    world.start(context: context)
  }

  func update(input: GameInput, deltaTime: TimeInterval) {
    world.update(input: input, deltaTime: deltaTime)
  }

  func render(context: GameContext) {
    world.render(context: context)
  }
}

