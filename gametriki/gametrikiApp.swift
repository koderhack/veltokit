//
//  gametrikiApp.swift
//  gametriki
//

import SwiftUI
import TrikiMotionKit

@main
struct gametrikiApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var tuning: GameTuning
  @StateObject private var motion: MotionInputProvider

  init() {
    let tuning = GameTuning()
    let motion = MotionInputProvider()
    GameManager.applyMode(.paddle, to: motion)
    _tuning = StateObject(wrappedValue: tuning)
    _motion = StateObject(wrappedValue: motion)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(tuning)
        .environmentObject(motion)
        .preferredColorScheme(.dark)
    }
  }
}
