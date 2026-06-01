import AudioToolbox
import AVFoundation
import Foundation

/// Efekty dźwiękowe quizu / teleturnieju (systemowe — bez plików).
enum QuizSFX {
  private static var prepared = false
  private static var lastFocusSound: TimeInterval = 0
  private static var lastHoldTickStep = -1

  static func prepare() {
    guard !prepared else { return }
    prepared = true
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)
  }

  /// Lobby, wybór kategorii, zmiana fokusu Triki.
  static func menuFocus() {
    playDebounced(1104, minInterval: 0.12)
  }

  /// Zatwierdzenie opcji w menu (hold / dotyk).
  static func menuConfirm() {
    play(1113)
  }

  static func modeToggle() {
    play(1016)
  }

  static func categorySelected() {
    play(1105)
  }

  static func loadingReady() {
    play(1036)
  }

  static func loadingError() {
    play(1053)
  }

  /// Start rundy / wejście w grę.
  static func roundStart() {
    play(1025)
  }

  /// Kolejne pytanie po feedbacku.
  static func nextQuestion() {
    play(1104)
  }

  /// Postęp hold przy zatwierdzaniu odpowiedzi (0…1).
  static func holdProgress(_ progress: Double) {
    let step: Int
    switch progress {
    case ..<0.34: step = 0
    case ..<0.67: step = 1
    case ..<0.95: step = 2
    default: step = 3
    }
    guard step > lastHoldTickStep else { return }
    lastHoldTickStep = step
    play(1057)
  }

  static func resetHoldTicks() {
    lastHoldTickStep = -1
  }

  static func answerLockIn() {
    play(1306)
  }

  static func correct() {
    play(1025)
  }

  static func wrong() {
    play(1053)
  }

  static func roundComplete() {
    play(1026)
  }

  static func gameOver() {
    play(1032)
  }

  static func tvConnected() {
    play(1105)
  }

  static func tvDisconnected() {
    play(1057)
  }

  private static func playDebounced(_ id: SystemSoundID, minInterval: TimeInterval) {
    let now = ProcessInfo.processInfo.systemUptime
    guard now - lastFocusSound >= minInterval else { return }
    lastFocusSound = now
    play(id)
  }

  private static func play(_ id: SystemSoundID) {
    prepare()
    AudioServicesPlaySystemSound(id)
  }
}
