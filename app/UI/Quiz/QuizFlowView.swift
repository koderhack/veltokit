import SwiftUI
import Translation
import VeltoKit

/// Wejście w quiz: lobby → kategoria → ładowanie → gra (kalibracja Triki automatyczna po BLE).
struct QuizFlowView: View {
  @ObservedObject var inputProvider: MotionInputProvider
  @ObservedObject var tuning: GameTuning
  @EnvironmentObject private var quizDisplay: QuizExternalDisplay

  @StateObject private var session = QuizSession()
  @StateObject private var loader = QuizLoader()
  @State private var categoryToLoad: QuizCategory?

  var body: some View {
    ZStack {
      ArcadeUI.screenBackground

      switch session.phase {
      case .lobby:
        QuizLobbyScreen(
          session: session,
          onStart: {
            session.resetScores()
            session.beginCategorySelection(from: loader.categories)
          },
          onToggleMode: {
            session.mode = session.mode == .solo ? .duo : .solo
            QuizSFX.modeToggle()
          }
        )
      case .categoryPick:
        QuizCategoryPickerScreen(session: session)
      case .loadingRound, .calibration:
        QuizLoadingScreen(loader: loader)
          .overlay {
            if session.phase == .loadingRound, let category = categoryToLoad {
              QuizRoundLoadTrigger(
                category: category,
                loader: loader,
                session: session
              ) {
                finishRoundLoad()
              }
            }
          }
      case .playing:
        QuizGameView(session: session, inputProvider: inputProvider, tuning: tuning)
      case .finished:
        QuizResultsScreen(
          session: session,
          onReplay: {
            session.resetScores()
            session.beginCategorySelection(from: loader.categories)
          },
          onMenu: { session.phase = .lobby }
        )
      }
    }
    .id(quizFlowTrikiIdentity)
    .navigationTitle("Quiz")
    .navigationBarTitleDisplayMode(.inline)
    .trikiUIScreen(itemCount: trikiItemCount, isActive: trikiNavigationActive) { index in
      handleTrikiActivate(index)
    }
    .task {
      await loader.loadCategoriesIfNeeded()
    }
    .onAppear {
      QuizSFX.prepare()
    }
    .onChange(of: session.phase) { oldPhase, phase in
      quizDisplay.setQuizActive(phase == .playing)
      handlePhaseSound(from: oldPhase, to: phase)
      if phase == .categoryPick, oldPhase != .lobby {
        session.beginCategorySelection(from: loader.categories)
      }
    }
  }

  private func handlePhaseSound(from oldPhase: QuizFlowPhase, to phase: QuizFlowPhase) {
    switch phase {
    case .categoryPick where oldPhase == .lobby:
      QuizSFX.menuConfirm()
    case .loadingRound:
      QuizSFX.categorySelected()
    case .playing where oldPhase == .loadingRound:
      QuizSFX.roundStart()
    case .finished:
      QuizSFX.gameOver()
    case .lobby where oldPhase == .finished:
      QuizSFX.menuFocus()
    default:
      break
    }
  }

  private var quizFlowTrikiIdentity: String {
    switch session.phase {
    case .categoryPick:
      return "category-\(session.categoryChoices.map(\.id))"
    default:
      return String(describing: session.phase)
    }
  }

  private var trikiNavigationActive: Bool {
    session.phase == .categoryPick
  }

  private var trikiItemCount: Int {
    max(1, session.categoryChoices.count)
  }

  private func handleTrikiActivate(_ index: Int) {
    switch session.phase {
    case .categoryPick:
      guard session.categoryChoices.indices.contains(index) else { return }
      pickCategory(session.categoryChoices[index])
    default:
      break
    }
  }

  private func pickCategory(_ category: QuizCategory) {
    categoryToLoad = category
    session.selectedCategory = category
    loader.beginRoundLoad(categoryName: category.namePL)
    session.phase = .loadingRound
  }

  private func finishRoundLoad() {
    categoryToLoad = nil
    guard !loader.roundQuestions.isEmpty else {
      QuizSFX.loadingError()
      session.beginCategorySelection(from: loader.categories)
      return
    }
    QuizSFX.loadingReady()
    session.applyLoadedRound(loader.roundQuestions)
  }
}

// MARK: - Lobby

private struct QuizLobbyScreen: View {
  @ObservedObject var session: QuizSession
  let onStart: () -> Void
  let onToggleMode: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Image(systemName: "brain.head.profile")
            .font(.system(size: 40, weight: .bold))
            .foregroundStyle(NeonTheme.neonMagenta)
          Text("QUIZ TRIKI")
            .font(.system(size: 26, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
          Text("Lobby: dotyk · Triki: kategorie i odpowiedzi")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 12)

        ArcadeUI.panel {
          VStack(alignment: .leading, spacing: 8) {
            ArcadeUI.sectionLabel("TRYB · \(session.mode.title)")
            Text(session.mode.subtitle)
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(.white.opacity(0.5))
          }
        }

        ArcadeUI.panel {
          VStack(alignment: .leading, spacing: 10) {
            ArcadeUI.sectionLabel("GRACZE (opcjonalnie klawiatura)")
            TextField("Nick gracza 1", text: $session.player1Name)
              .textFieldStyle(.roundedBorder)
            if session.mode == .duo {
              TextField("Nick gracza 2", text: $session.player2Name)
                .textFieldStyle(.roundedBorder)
            }
          }
        }

        QuizDisplayShareRow(session: session)

        ArcadeUI.primaryButton("START", icon: "play.fill", action: onStart)
        ArcadeUI.secondaryButton(
          "ZMIEŃ TRYB · \(session.mode.title)",
          tint: NeonTheme.neonMagenta,
          action: onToggleMode
        )
      }
      .padding(16)
    }
  }
}

// MARK: - Category

private struct QuizCategoryPickerScreen: View {
  @ObservedObject var session: QuizSession

  var body: some View {
    VStack(spacing: 12) {
      Text(session.roundLabel())
        .font(.system(size: 12, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonCyan)

      if session.mode == .duo {
        Text("\(session.categoryPickerName()) wybiera kategorię dla \(session.categoryTargetName())")
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      } else {
        Text("Losowe 4 kategorie · 10 pytań")
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.white.opacity(0.7))
      }

      Text("Triki: obrót + hold lub przycisk · dotyk też działa")
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonCyan.opacity(0.85))
        .multilineTextAlignment(.center)
        .padding(.horizontal)

      VStack(spacing: 8) {
        ForEach(Array(session.categoryChoices.enumerated()), id: \.element.id) { offset, cat in
          TrikiFocusRow(
            index: offset,
            title: cat.namePL,
            accent: NeonTheme.neonCyan,
            icon: "folder.fill"
          )
        }
      }
      .padding(.horizontal, 12)

      Spacer(minLength: 0)
    }
    .padding(.top, 8)
  }
}

private struct QuizLoadingScreen: View {
  @ObservedObject var loader: QuizLoader

  var body: some View {
    VStack(spacing: 20) {
      if loader.progress > 0 {
        ProgressView(value: Double(loader.progress), total: 100)
          .tint(NeonTheme.neonCyan)
          .frame(maxWidth: 280)
      } else {
        ProgressView()
          .controlSize(.large)
          .tint(NeonTheme.neonCyan)
      }

      Text(loader.statusMessage)
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.85))
        .multilineTextAlignment(.center)

      if loader.isLoadingRound, loader.progress > 0 {
        Text("\(loader.progress)%")
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(NeonTheme.neonYellow)
      }

      if let err = loader.errorMessage {
        Text(err)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
  }
}

/// Uruchamia `.translationTask` przy każdej nowej kategorii (rootowy task nie restartował się sam).
private struct QuizRoundLoadTrigger: View {
  let category: QuizCategory
  @ObservedObject var loader: QuizLoader
  @ObservedObject var session: QuizSession
  let onComplete: () -> Void

  @State private var translationConfiguration = TranslationSession.Configuration(
    source: Locale.Language(identifier: "en"),
    target: Locale.Language(identifier: "pl")
  )

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .accessibilityHidden(true)
      .translationTask(translationConfiguration) { translationSession in
        let count = session.mode == .solo ? QuizRules.questionsPerRound : 1
        await loader.loadRound(
          category: category,
          questionCount: count,
          translationSession: translationSession
        )
        onComplete()
      }
      .id(category.id)
  }
}

// MARK: - Wyniki

struct QuizResultsScreen: View {
  @ObservedObject var session: QuizSession
  let onReplay: () -> Void
  let onMenu: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Text("KONIEC GRY")
        .font(.system(size: 24, weight: .heavy, design: .monospaced))
        .foregroundStyle(NeonTheme.neonCyan)

      Text(session.scoreboardLine())
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .foregroundStyle(.white)

      QuizDisplayShareRow(session: session)

      ArcadeUI.primaryButton("JESZCZE RAZ", icon: "arrow.clockwise", action: onReplay)
      ArcadeUI.secondaryButton("MENU GŁÓWNE", tint: NeonTheme.neonCyan, action: onMenu)
    }
    .padding(24)
  }
}

// MARK: - TV / udostępnianie

struct QuizDisplayShareRow: View {
  @ObservedObject var session: QuizSession

  var body: some View {
    VStack(spacing: 12) {
      QuizTVConnectPanel()
      ShareLink(item: session.shareSummary()) {
        Label("Udostępnij wynik", systemImage: "square.and.arrow.up")
          .font(.system(size: 13, weight: .bold, design: .monospaced))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .background(NeonTheme.neonMagenta.opacity(0.18))
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .stroke(NeonTheme.neonMagenta.opacity(0.45), lineWidth: 1)
          )
      }
      .foregroundStyle(NeonTheme.neonMagenta)
    }
  }
}
