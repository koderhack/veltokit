import Foundation

@MainActor
public protocol InputProvider: AnyObject {
  func pollInput(deltaTime: TimeInterval?) -> GameInput
}

extension InputProvider {
  public func pollInput() -> GameInput {
    pollInput(deltaTime: nil)
  }
}
