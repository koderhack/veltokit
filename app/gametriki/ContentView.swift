/// Glowne wejscie UI aplikacji.

//
//  ContentView.swift
//  gametriki
//

import SwiftUI
import VeltoKit

/// Reprezentuje typ `ContentView`.
struct ContentView: View {
/// Przechowuje wartosc `body`.
  var body: some View {
    MainMenu()
  }
}

#Preview {
  /// Stores `tuning` used by this scope.
  let tuning = GameTuning()
  ContentView()
    .environmentObject(tuning)
    .environmentObject(MotionInputProvider())
    .environmentObject(TrikiUINavigator())
}
