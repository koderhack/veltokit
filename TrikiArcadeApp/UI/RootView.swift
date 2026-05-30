import SwiftUI
import TrikiMotionKit

private let rootInputRefreshInterval = 1.00

struct RootView: View {
  @EnvironmentObject private var tuning: GameTuning
  @EnvironmentObject private var motion: MotionInputProvider

  @State private var showConnect = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color(red: 0.04, green: 0.04, blue: 0.08).ignoresSafeArea()

        VStack(spacing: 16) {
          header
          connectionCard
          gamesList
          devModeEntry
          Spacer(minLength: 0)
        }
        .padding(16)
      }
      .navigationTitle("PIXEL ARCADE")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showConnect = true
          } label: {
            Label("BLE", systemImage: "dot.radiowaves.left.and.right")
          }
        }
      }
      .sheet(isPresented: $showConnect) {
        ConnectView()
          .presentationDetents([.medium, .large])
      }
      .background(
        TimelineView(.periodic(from: .now, by: rootInputRefreshInterval)) { timeline in
          Color.clear
            .onChange(of: timeline.date.timeIntervalSinceReferenceDate, initial: true) { _, _ in
              _ = motion.pollInput()
            }
        }
      )
    }
  }

  private var header: some View {
    Text("160×90 • pixel engine")
      .font(.system(size: 12, weight: .bold, design: .monospaced))
      .foregroundStyle(Color.cyan)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var connectionCard: some View {
    let input = motion.liveInput
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(motion.isConnected ? "Połączono" : "Nie połączono")
          .font(.system(size: 13, weight: .bold, design: .monospaced))
        Spacer()
        Text(motion.isConnected ? "CONNECTED" : "NOT CONNECTED")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .foregroundStyle(motion.isConnected ? .green : .orange)
      }

      HStack(spacing: 6) {
        meter("relX", input.deltaX)
        meter("pos", input.posX)
      }
      Text("tryb: \(motion.config.mode.rawValue)")
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(.cyan)

      Text(motion.isReceiving ? "● Odbieram pakiety BLE" : "○ Brak pakietów — połącz Triki")
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(motion.isReceiving ? .green : .red)
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

  private var devModeEntry: some View {
    NavigationLink {
      DevModeView()
    } label: {
      HStack {
        Text("DEV MODE")
          .font(.system(size: 12, weight: .bold, design: .monospaced))
        Spacer()
        Image(systemName: "chevron.right")
      }
      .foregroundStyle(.white)
      .padding(12)
      .background(Color.orange.opacity(0.25))
      .overlay(Rectangle().stroke(Color.orange.opacity(0.5), lineWidth: 1))
    }
    .buttonStyle(.plain)
  }

  private var gamesList: some View {
    VStack(spacing: 8) {
      Text("PLATFORMA GIER")
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .foregroundStyle(.cyan)
        .frame(maxWidth: .infinity, alignment: .leading)
      ForEach(GameType.platformGames) { gameType in
        NavigationLink {
          GameCalibrationView(gameType: gameType, inputProvider: motion, tuning: tuning)
        } label: {
          HStack {
            Text(gameType.rawValue.uppercased())
              .font(.system(size: 14, weight: .heavy, design: .monospaced))
            Spacer()
            Image(systemName: "play.fill")
          }
          .foregroundStyle(.black)
          .padding(12)
          .background(Color.cyan)
        }
        .buttonStyle(.plain)
      }
    }
  }
}
