//
//  gametrikiApp.swift
//  gametriki
//

import SwiftUI
import VeltoKit

@main
struct gametrikiApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var tuning: GameTuning
  @StateObject private var motion: MotionInputProvider
  @StateObject private var trikiUI: TrikiUINavigator
  @StateObject private var quizDisplay: QuizExternalDisplay

  init() {
    ArcadeTVSettings.registerDefaults()
    let tuning = GameTuning()
    let motion = MotionInputProvider()
    _tuning = StateObject(wrappedValue: tuning)
    _motion = StateObject(wrappedValue: motion)
    _trikiUI = StateObject(wrappedValue: TrikiUINavigator())
    _quizDisplay = StateObject(wrappedValue: QuizExternalDisplay())
  }

  var body: some Scene {
    WindowGroup {
      MainMenu()
        .environmentObject(tuning)
        .environmentObject(motion)
        .environmentObject(trikiUI)
        .environmentObject(quizDisplay)
        .preferredColorScheme(.dark)
    }
  }
}
