//
//  ContentView.swift
//  gametriki
//

import SwiftUI
import VeltoKit

struct ContentView: View {
  var body: some View {
    MainMenu()
  }
}

#Preview {
  let tuning = GameTuning()
  ContentView()
    .environmentObject(tuning)
    .environmentObject(MotionInputProvider())
    .environmentObject(TrikiUINavigator())
}
