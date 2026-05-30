import SwiftUI
import QuartzCore

/// Stały tick ~60 FPS (CADisplayLink).
struct DisplayLinkView: UIViewRepresentable {
  let onFrame: @MainActor (TimeInterval) -> Void

  func makeUIView(context: Context) -> DisplayLinkHostView {
    let view = DisplayLinkHostView()
    view.onFrame = onFrame
    return view
  }

  func updateUIView(_ uiView: DisplayLinkHostView, context: Context) {
    uiView.onFrame = onFrame
  }
}

final class DisplayLinkHostView: UIView {
  var onFrame: (@MainActor (TimeInterval) -> Void)?
  private var link: CADisplayLink?
  private var frameInFlight = false

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
    guard !frameInFlight else { return }
    frameInFlight = true
    defer { frameInFlight = false }
    let callback = onFrame
    MainActor.assumeIsolated {
      callback?(sender.timestamp)
    }
  }

  deinit {
    link?.invalidate()
  }
}

/// Modyfikator pętli gry — podłącz pod widok z `GameEngine`.
struct GameLoop: ViewModifier {
  let onTick: @MainActor (TimeInterval) -> Void

  func body(content: Content) -> some View {
    content.background {
      DisplayLinkView(onFrame: onTick)
        .allowsHitTesting(false)
    }
  }
}

extension View {
  func gameLoop(onTick: @escaping @MainActor (TimeInterval) -> Void) -> some View {
    modifier(GameLoop(onTick: onTick))
  }
}
