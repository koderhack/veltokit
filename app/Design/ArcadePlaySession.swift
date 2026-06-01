import SwiftUI

/// Włącza muzykę sesji i blokuje wygaszanie ekranu.
struct ArcadePlaySessionModifier: ViewModifier {
  let isActive: Bool
  var music: ArcadePlayMusic = .dartGame

  @AppStorage(ArcadeSettings.backgroundMusicEnabledKey) private var backgroundMusicEnabled = false

  enum ArcadePlayMusic {
    case dartLobby
    case dartGame
    case bowlingLobby
    case bowlingGame
    case none
  }

  func body(content: Content) -> some View {
    content
      .onAppear { sync(active: isActive) }
      .onDisappear { teardown() }
      .onChange(of: isActive) { _, active in
        sync(active: active)
      }
      .onChange(of: backgroundMusicEnabled) { _, _ in
        sync(active: isActive)
      }
  }

  private func sync(active: Bool) {
    if active {
      ScreenAwake.push()
      startMusicIfEnabled()
    } else {
      teardown()
    }
  }

  private func startMusicIfEnabled() {
    guard backgroundMusicEnabled else {
      ArcadeAudio.stopMusic()
      return
    }
    switch music {
    case .dartLobby: ArcadeAudio.startDartLobbyMusic()
    case .dartGame: ArcadeAudio.startDartGameMusic()
    case .bowlingLobby: ArcadeAudio.startBowlingLobbyMusic()
    case .bowlingGame: ArcadeAudio.startBowlingGameMusic()
    case .none: break
    }
  }

  private func teardown() {
    ScreenAwake.pop()
    ArcadeAudio.stopMusic()
  }
}

extension View {
  func arcadePlaySession(active: Bool, music: ArcadePlaySessionModifier.ArcadePlayMusic = .dartGame) -> some View {
    modifier(ArcadePlaySessionModifier(isActive: active, music: music))
  }
}
