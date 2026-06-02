import Foundation
import VeltoKit

/// Minimalny wektor 2D do pozycji i ruchu.
struct Vec2: Equatable {
/// Przechowuje wartosc `x`.
  var x: Double
/// Przechowuje wartosc `y`.
  var y: Double

/// Przechowuje wartosc `zero`.
  static let zero = Vec2(x: 0, y: 0)

/// Wykonuje operacje `+`.
  static func + (lhs: Vec2, rhs: Vec2) -> Vec2 { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
/// Wykonuje operacje `*`.
  static func * (lhs: Vec2, rhs: Double) -> Vec2 { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
}

/// Minimalny odpowiednik "Node"/"GameObject" (inspiracja Godot).
/// Dev implementuje tylko `update` i `render`.
@MainActor
/// Reprezentuje typ `GameObject`.
class GameObject: Identifiable {
/// Przechowuje wartosc `id`.
  let id = UUID()

/// Przechowuje wartosc `position`.
  var position: Vec2
/// Przechowuje wartosc `isActive`.
  var isActive: Bool = true

/// Inicjalizuje nowa instancje.
  init(position: Vec2 = .zero) {
    self.position = position
  }

/// Wykonuje operacje `start`.
  func start(context: GameContext) {
    // opcjonalnie w subclass
  }

/// Wykonuje operacje `update`.
  func update(input: GameInput, deltaTime: TimeInterval) {
    // opcjonalnie w subclass
    // Dev używa input.rotation / input.moveX / input.moveY / input.shake / input.action
  }

/// Wykonuje operacje `render`.
  func render(context: GameContext) {
    // opcjonalnie w subclass
  }
}

/// Najprostsza "scena/świat" zarządzająca obiektami.
/// To jest celowo małe: bez fizyki, bez edytora, bez drzewa scen.
@MainActor
/// Reprezentuje typ `GameWorld`.
final class GameWorld {
/// Przechowuje wartosc `objects`.
  private(set) var objects: [GameObject] = []

/// Wykonuje operacje `add`.
  func add(_ object: GameObject) {
    objects.append(object)
  }

/// Wykonuje operacje `removeInactive`.
  func removeInactive() {
    objects.removeAll { !$0.isActive }
  }

/// Wykonuje operacje `start`.
  func start(context: GameContext) {
    for o in objects where o.isActive {
      o.start(context: context)
    }
  }

/// Wykonuje operacje `update`.
  func update(input: GameInput, deltaTime: TimeInterval) {
    for o in objects where o.isActive {
      o.update(input: input, deltaTime: deltaTime)
    }
    removeInactive()
  }

/// Wykonuje operacje `render`.
  func render(context: GameContext) {
    for o in objects where o.isActive {
      o.render(context: context)
    }
  }
}

/// Gotowy adapter: implementuje `Game` przez `GameWorld`.
/// Dev może zrobić własną grę jako: `final class MyGame: WorldGame { ... }`
@MainActor
/// Reprezentuje typ `WorldGame`.
class WorldGame: Game {
/// Przechowuje wartosc `world`.
  let world = GameWorld()

/// Przechowuje wartosc `name`.
  var name: String { "WorldGame" }
/// Przechowuje wartosc `inputProfile`.
  var inputProfile: GameInputProfile { .default }

/// Wykonuje operacje `start`.
  func start(context: GameContext) {
    world.start(context: context)
  }

/// Wykonuje operacje `update`.
  func update(input: GameInput, deltaTime: TimeInterval) {
    world.update(input: input, deltaTime: deltaTime)
  }

/// Wykonuje operacje `render`.
  func render(context: GameContext) {
    world.render(context: context)
  }
}

