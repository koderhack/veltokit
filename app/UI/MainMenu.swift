import SwiftUI
import VeltoKit

private enum MainMenuRoute: String, Hashable {
  case pong
  case dart
  case quiz
  case bowling
  case dev
}

/// Opisuje struct `MainMenu` używany przez warstwę UI i logikę gry.
struct MainMenu: View {
  @EnvironmentObject private var tuning: GameTuning
  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay

  @State private var path: [MainMenuRoute] = []
  @State private var showConnect = false
  @AppStorage(ArcadeSettings.backgroundMusicEnabledKey) private var backgroundMusicEnabled = false

  /// Przechowuje wartość `body` wykorzystywaną przez dany komponent.
  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        ArcadeUI.screenBackground

        ScrollView(showsIndicators: false) {
          VStack(spacing: 12) {
            header
            connectionCard

            VStack(spacing: 8) {
              Text("MENU — dotyk")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(NeonTheme.neonCyan)
                .frame(maxWidth: .infinity, alignment: .leading)

              menuGameButton(route: .pong, title: "PONG", subtitle: "Paletka · żyroskop", accent: NeonTheme.neonCyan, icon: "circle.grid.cross.fill")
              menuGameButton(route: .dart, title: "DART", subtitle: "1–2 graczy · na zmianę · Triki", accent: .green, icon: "target")
              menuGameButton(route: .quiz, title: "QUIZ", subtitle: "TV + Triki na kategoriach i w grze", accent: NeonTheme.neonMagenta, icon: "questionmark.square.fill")
              menuGameButton(route: .bowling, title: "BOWLING", subtitle: "3D · 1–4 graczy · Triki", accent: Color.orange, icon: "circle.circle.fill")
              menuGameButton(route: .dev, title: "DEV MODE", subtitle: "Diagnostyka BLE", accent: .orange, icon: "wrench.and.screwdriver.fill")

              Button {
                showConnect = true
              } label: {
                ArcadeUI.gameCard(
                  title: "POŁĄCZ BLE",
                  subtitle: motion.isConnected ? "Połączono" : "Skanuj Triki",
                  accent: motion.isConnected ? NeonTheme.neonGreen : NeonTheme.neonOrange,
                  icon: "dot.radiowaves.left.and.right"
                )
              }
              .buttonStyle(.plain)
            }
          }
          .padding(16)
        }
      }
      .navigationTitle("PIXEL ARCADE")
      .navigationBarTitleDisplayMode(.large)
      .navigationDestination(for: MainMenuRoute.self) { route in
        gameDestination(for: route)
      }
      .sheet(isPresented: $showConnect) {
        ConnectView()
          .presentationDetents([.medium, .large])
      }
    }
    .environmentObject(motion)
    .environmentObject(tuning)
    .environmentObject(trikiUI)
    .environmentObject(quizDisplay)
    .motionInputPolling(motion)
  }

  @ViewBuilder
  private func gameDestination(for route: MainMenuRoute) -> some View {
    switch route {
    case .pong:
      GameCalibrationView(gameType: .pong)
    case .dart:
      GameCalibrationView(gameType: .dart)
    case .quiz:
      QuizFlowView(inputProvider: motion, tuning: tuning)
    case .bowling:
      GameCalibrationView(gameType: .bowling)
    case .dev:
      DevModeView()
    }
  }

  private var header: some View {
    Text("Dotknij kartę — wybierz grę")
      .font(.system(size: 11, weight: .bold, design: .monospaced))
      .foregroundStyle(Color.cyan)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var connectionCard: some View {
    let input = motion.liveInput
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(motion.isConnected ? "Połączono" : "Nie połączono")
            .font(.system(size: 13, weight: .bold, design: .monospaced))
          if motion.isConnected {
            Text("BLE: \(motion.bleMode.statusLabel)")
              .font(.system(size: 9, weight: .semibold, design: .monospaced))
              .foregroundStyle(motion.bleMode.uiColor)
          }
          if let idle = motion.idleStatusMessage {
            Text(idle)
              .font(.system(size: 9, design: .monospaced))
              .foregroundStyle(NeonTheme.neonOrange)
          } else if motion.isTrikiGameplayActive {
            Text("Gotowy do gry")
              .font(.system(size: 9, weight: .semibold, design: .monospaced))
              .foregroundStyle(NeonTheme.neonGreen)
          }
        }
        Spacer()
        Circle()
          .fill(motion.linkIndicatorColor)
          .frame(width: 8, height: 8)
      }
      HStack(spacing: 6) {
        meter("posX", input.posX)
        meter("BLE", motion.isTrikiGameplayActive ? 1 : (motion.isReceiving ? 0.5 : 0))
      }

      Toggle(isOn: $backgroundMusicEnabled) {
        Text("Muzyka w Dart")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
      }
      .tint(NeonTheme.neonMagenta)
      .onChange(of: backgroundMusicEnabled) { _, enabled in
        ArcadeSettings.backgroundMusicEnabled = enabled
        if !enabled { ArcadeAudio.stopMusic() }
      }
    }
    .foregroundStyle(.white)
    .padding(12)
    .background(Color.white.opacity(0.06))
    .overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
  }

  private func meter(_ label: String, _ value: Double) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.system(size: 9, design: .monospaced))
        .opacity(0.7)
      Text(String(format: "%+.2f", value))
        .font(.system(size: 11, weight: .bold, design: .monospaced))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func menuGameButton(
    route: MainMenuRoute,
    title: String,
    subtitle: String,
    accent: Color,
    icon: String
  ) -> some View {
    Button {
      path.append(route)
    } label: {
      ArcadeUI.gameCard(
        title: title,
        subtitle: subtitle,
        accent: accent,
        icon: icon
      )
    }
    .buttonStyle(.plain)
  }
}
