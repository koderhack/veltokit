//
//  ContentView.swift
//  gametriki
//

import SwiftUI
import TrikiMotionKit

struct ContentView: View {
  var body: some View {
    RootView()
  }
}

#Preview {
  let tuning = GameTuning()
  ContentView()
    .environmentObject(tuning)
    .environmentObject(MotionInputProvider())
}
