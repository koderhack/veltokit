import AudioToolbox
import AVFoundation
import Foundation

/// Muzyka arcade (generowana) + efekty dart / kalibracji / publiczność.
@MainActor
enum ArcadeAudio {
  private static var prepared = false
  private static var musicEngine: AVAudioEngine?
  private static var musicPlayer: AVAudioPlayerNode?
  private static var musicVolume: Float = 0.22

  static func prepare() {
    guard !prepared else { return }
    prepared = true
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)
  }

  // MARK: - Muzyka

  static func startDartLobbyMusic() {
    startLoop(volume: 0.16, tempo: 96)
  }

  static func startDartGameMusic() {
    startLoop(volume: 0.24, tempo: 112)
  }

  static func startBowlingLobbyMusic() {
    startBowlingLoop(volume: 0.17, tempo: 88)
  }

  static func startBowlingGameMusic() {
    startBowlingLoop(volume: 0.26, tempo: 104)
  }

  static func stopMusic() {
    musicPlayer?.stop()
    musicEngine?.stop()
    musicPlayer = nil
    musicEngine = nil
  }

  private static func startLoop(volume: Float, tempo: Double) {
    prepare()
    stopMusic()
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
          let buffer = makeArcadeLoopBuffer(format: format, tempo: tempo) else { return }

    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = volume
    musicVolume = volume

    do {
      try engine.start()
      player.scheduleBuffer(buffer, at: nil, options: .loops)
      player.play()
      musicEngine = engine
      musicPlayer = player
    } catch {
      musicEngine = nil
      musicPlayer = nil
    }
  }

  // MARK: - Efekty

  static func calibrationStep() {
    play(1104)
  }

  static func calibrationDone() {
    play(1025)
    applause(bursts: 2)
  }

  static func dartThrowWhoosh() {
    playDebounced(1057, minInterval: 0.2)
  }

  static func dartHit(points: Int) {
    if points >= 25 {
      play(1113)
      applause(bursts: 1)
    } else if points > 0 {
      play(1109)
    } else {
      play(1053)
    }
  }

  static func dartBust() {
    play(1053)
  }

  static func dartWin() {
    play(1025)
    applause(bursts: 4)
  }

  static func turnChange() {
    play(1016)
    applause(bursts: 1)
  }

  static func bowlingThrow() {
    playDebounced(1057, minInterval: 0.25)
  }

  static func bowlingHit() {
    playDebounced(1105, minInterval: 0.06)
  }

  static func bowlingStrike() {
    play(1113)
    applause(bursts: 4)
  }

  static func bowlingSpare() {
    play(1109)
    applause(bursts: 3)
  }

  static func bowlingCrowdCheer(pinsDown: Int) {
    guard pinsDown > 0 else { return }
    if pinsDown >= 8 {
      applause(bursts: 3)
    } else if pinsDown >= 5 {
      applause(bursts: 2)
    } else if pinsDown >= 3 {
      applause(bursts: 1)
    }
  }

  static func bowlingWin() {
    play(1025)
    applause(bursts: 5)
  }

  /// Kaskada dźwięków przy przewróconych kręglach (po zatrzymaniu kuli).
  static func bowlingPinsKnocked(count: Int) {
    guard count > 0 else { return }
    prepare()
    let pinClack: [SystemSoundID] = [1105, 1053, 1109, 1111, 1113, 1104]
    let hits = min(count, 8)
    for i in 0..<hits {
      let delay = Double(i) * 0.045
      let sound = pinClack[min(i, pinClack.count - 1)]
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        AudioServicesPlaySystemSound(sound)
      }
    }
    if count >= 10 {
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 180_000_000)
        play(1113)
      }
    } else if count >= 6 {
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: 120_000_000)
        play(1109)
      }
    }
  }

  static func applause(bursts: Int = 3) {
    prepare()
    let ids: [SystemSoundID] = [1111, 1112, 1113, 1105, 1109, 1025, 1104]
    let count = max(1, min(6, bursts))
    for i in 0..<count {
      let delay = Double(i) * 0.09
      Task { @MainActor in
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        AudioServicesPlaySystemSound(ids[i % ids.count])
      }
    }
  }

  // MARK: - Generowanie pętli chiptune

  private static func makeArcadeLoopBuffer(format: AVAudioFormat, tempo: Double) -> AVAudioPCMBuffer? {
    let sampleRate = format.sampleRate
    let beat = 60.0 / tempo
    let bars = 2.0
    let duration = beat * 4 * bars
    let frameCount = AVAudioFrameCount(sampleRate * duration)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
    buffer.frameLength = frameCount

    guard let channel = buffer.floatChannelData?[0] else { return nil }

    let melody: [(beatOffset: Double, midi: Int, len: Double, gain: Float)] = [
      (0, 60, 0.45, 0.35),
      (0.5, 63, 0.45, 0.28),
      (1, 67, 0.45, 0.32),
      (1.5, 65, 0.45, 0.28),
      (2, 60, 0.45, 0.35),
      (2.5, 58, 0.45, 0.28),
      (3, 55, 0.9, 0.38),
      (4, 60, 0.45, 0.35),
      (4.5, 63, 0.45, 0.28),
      (5, 67, 0.45, 0.32),
      (5.5, 70, 0.45, 0.30),
      (6, 67, 0.45, 0.32),
      (6.5, 65, 0.45, 0.28),
      (7, 60, 0.9, 0.36),
    ]

    let bassPattern = [43, 43, 48, 50, 43, 41, 38, 38]

    for frame in 0..<Int(frameCount) {
      let t = Double(frame) / sampleRate
      let beatIndex = t / beat
      var sample: Float = 0

      let bassMidi = bassPattern[Int(beatIndex) % bassPattern.count]
      let bassFreq = midiToHz(bassMidi)
      sample += square(t, freq: bassFreq, gain: 0.12)

      for note in melody {
        let start = note.beatOffset * beat
        let end = start + note.len * beat
        guard t >= start, t < end else { continue }
        let freq = midiToHz(note.midi)
        let env = envelope(t - start, duration: note.len * beat)
        sample += square(t, freq: freq, gain: note.gain * env)
      }

      sample = max(-0.85, min(0.85, sample * 0.55))
      channel[frame] = sample
    }

    return buffer
  }

  /// Bowling — wolniejszy bas, inna melodia niż dart.
  private static func startBowlingLoop(volume: Float, tempo: Double) {
    prepare()
    stopMusic()
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
          let buffer = makeBowlingLoopBuffer(format: format, tempo: tempo) else { return }

    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: format)
    engine.mainMixerNode.outputVolume = volume
    musicVolume = volume

    do {
      try engine.start()
      player.scheduleBuffer(buffer, at: nil, options: .loops)
      player.play()
      musicEngine = engine
      musicPlayer = player
    } catch {
      musicEngine = nil
      musicPlayer = nil
    }
  }

  private static func makeBowlingLoopBuffer(format: AVAudioFormat, tempo: Double) -> AVAudioPCMBuffer? {
    let sampleRate = format.sampleRate
    let beat = 60.0 / tempo
    let duration = beat * 8
    let frameCount = AVAudioFrameCount(sampleRate * duration)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
    buffer.frameLength = frameCount
    guard let channel = buffer.floatChannelData?[0] else { return nil }

    let melody: [(beatOffset: Double, midi: Int, len: Double, gain: Float)] = [
      (0, 55, 0.9, 0.30),
      (1, 58, 0.45, 0.26),
      (1.5, 60, 0.45, 0.28),
      (2, 62, 0.9, 0.32),
      (3, 60, 0.45, 0.26),
      (3.5, 58, 0.45, 0.24),
      (4, 55, 1.2, 0.34),
      (5.5, 53, 0.45, 0.22),
      (6, 55, 0.45, 0.24),
      (6.5, 58, 0.45, 0.26),
      (7, 62, 1.0, 0.30),
    ]
    let bassPattern = [36, 36, 41, 43, 36, 34, 31, 31]

    for frame in 0..<Int(frameCount) {
      let t = Double(frame) / sampleRate
      let beatIndex = t / beat
      var sample: Float = 0
      let bassMidi = bassPattern[Int(beatIndex) % bassPattern.count]
      sample += square(t, freq: midiToHz(bassMidi), gain: 0.16)
      for note in melody {
        let start = note.beatOffset * beat
        let end = start + note.len * beat
        guard t >= start, t < end else { continue }
        let env = envelope(t - start, duration: note.len * beat)
        sample += square(t, freq: midiToHz(note.midi), gain: note.gain * env)
      }
      channel[frame] = max(-0.85, min(0.85, sample * 0.52))
    }
    return buffer
  }

  private static func midiToHz(_ midi: Int) -> Double {
    440 * pow(2, Double(midi - 69) / 12)
  }

  private static func square(_ t: Double, freq: Double, gain: Float) -> Float {
    let phase = t * freq
    return (sin(2 * .pi * phase) >= 0 ? gain : -gain)
  }

  private static func envelope(_ t: Double, duration: Double) -> Float {
    let attack = min(1, t / 0.02)
    let releaseStart = max(0, duration - 0.06)
    let release = t > releaseStart ? Float(1 - (t - releaseStart) / 0.06) : 1
    return Float(attack) * max(0, release)
  }

  private static var lastDebounced: TimeInterval = 0

  private static func playDebounced(_ id: SystemSoundID, minInterval: TimeInterval) {
    let now = ProcessInfo.processInfo.systemUptime
    guard now - lastDebounced >= minInterval else { return }
    lastDebounced = now
    play(id)
  }

  private static func play(_ id: SystemSoundID) {
    prepare()
    AudioServicesPlaySystemSound(id)
  }
}
