/// Petla czasowa gry i synchronizacja klatek.

import SwiftUI
import QuartzCore

/// Stały tick ~60 FPS (CADisplayLink).
struct DisplayLinkView: UIViewRepresentable {
/// Przechowuje wartosc `onFrame`.
  let onFrame: @MainActor (TimeInterval) -> Void

/// Wykonuje operacje `makeUIView`.
  func makeUIView(context: Context) -> DisplayLinkHostView {
    let view = DisplayLinkHostView()
    view.onFrame = onFrame
    return view
  }

/// Wykonuje operacje `updateUIView`.
  func updateUIView(_ uiView: DisplayLinkHostView, context: Context) {
    uiView.onFrame = onFrame
  }
}

/// Reprezentuje typ `DisplayLinkHostView`.
final class DisplayLinkHostView: UIView {
/// Przechowuje wartosc `onFrame`.
  var onFrame: (@MainActor (TimeInterval) -> Void)?
  private var link: CADisplayLink?

  override init(frame: CGRect) {
    super.init(frame: frame)
    isUserInteractionEnabled = false
    backgroundColor = .clear
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      startLink()
    } else {
      stopLink()
    }
  }

  private func startLink() {
    guard link == nil else { return }
    let displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
    displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 50, maximum: 120, preferred: 60)
    displayLink.add(to: .main, forMode: .common)
    link = displayLink
  }

  private func stopLink() {
    link?.invalidate()
    link = nil
  }

  @objc private func tick(_ sender: CADisplayLink) {
/// Przechowuje wartosc `timestamp`.
    let timestamp = sender.timestamp
/// Przechowuje wartosc `callback`.
    let callback = onFrame
    DispatchQueue.main.async {
      callback?(timestamp)
    }
  }

/// Zwalnia zasoby podczas usuwania instancji.
  deinit {
    link?.invalidate()
  }
}

/// Modyfikator pętli gry — podłącz pod widok z `GameEngine`.
struct GameLoop: ViewModifier {
/// Przechowuje wartosc `onTick`.
  let onTick: @MainActor (TimeInterval) -> Void

/// Wykonuje operacje `body`.
  func body(content: Content) -> some View {
    content.background {
      DisplayLinkView(onFrame: onTick)
        .allowsHitTesting(false)
    }
  }
}

/// Rozszerza istniejacy typ o dodatkowe zachowanie.
extension View {
/// Wykonuje operacje `gameLoop`.
  func gameLoop(onTick: @escaping @MainActor (TimeInterval) -> Void) -> some View {
    modifier(GameLoop(onTick: onTick))
  }
}
