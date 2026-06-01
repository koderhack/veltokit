import SwiftUI
import VeltoKit

// MARK: - Ekran z nawigacją Triki

struct TrikiUIScreenModifier: ViewModifier {
  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator

  let itemCount: Int
  let isActive: Bool
  /// Gdy `false` (np. menu na TV), Triki nadal działa w tle, ale bez HUD na telefonie.
  let showsPhoneHUD: Bool
  let onActivate: (Int) -> Void

  func body(content: Content) -> some View {
    let hudVisible = isActive && showsPhoneHUD && trikiUI.isConfigured && !trikiUI.isSuspended
    content
      .padding(.bottom, hudVisible ? TrikiUIConfig.bottomContentInset : 0)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if hudVisible {
          TrikiUIHUD()
        }
      }
      .gameLoop { now in
        guard isActive else { return }
        trikiUI.tick(motion: motion, now: now)
      }
      .onAppear {
        guard isActive else { return }
        activateScreen()
      }
      .onChange(of: isActive) { _, active in
        if active {
          activateScreen()
        } else {
          trikiUI.clear()
        }
      }
      .onChange(of: itemCount) { _, _ in
        guard isActive else { return }
        activateScreen()
      }
  }

  private func activateScreen() {
    GameManager.applyUIMode(to: motion)
    trikiUI.isSuspended = false
    trikiUI.resetClock()
    trikiUI.configure(itemCount: itemCount, onActivate: onActivate)
  }
}

extension View {
  func trikiUIScreen(
    itemCount: Int,
    isActive: Bool = true,
    showsPhoneHUD: Bool = true,
    onActivate: @escaping (Int) -> Void
  ) -> some View {
    modifier(
      TrikiUIScreenModifier(
        itemCount: itemCount,
        isActive: isActive,
        showsPhoneHUD: showsPhoneHUD,
        onActivate: onActivate
      )
    )
  }
}

// MARK: - HUD

struct TrikiUIHUD: View {
  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator

  var body: some View {
    if trikiUI.isConfigured, !trikiUI.isSuspended {
      VStack(spacing: 6) {
        if motion.isTrikiControlAvailable {
          HStack(spacing: 8) {
            Image(systemName: "arrow.left.and.right")
              .foregroundStyle(NeonTheme.neonCyan)
            Text(trikiUI.focusIndex == nil ? "Wyprostuj Triki — wybór" : "Hold lub przycisk = OK")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
            Spacer()
            Text("pos \(String(format: "%+.2f", motion.liveInput.posX))")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
              .foregroundStyle(NeonTheme.neonYellow)
          }
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Rectangle().fill(Color.white.opacity(0.12))
              Rectangle()
                .fill(NeonTheme.neonMagenta)
                .frame(width: geo.size.width * trikiUI.holdProgress)
            }
          }
          .frame(height: 4)
        } else {
          HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
              .foregroundStyle(NeonTheme.neonMagenta)
            Text("Dotknij wiersz — od razu")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
            Spacer()
          }
        }
        Group {
          if motion.isTrikiControlAvailable {
            Text("Obrót = wybór · hold lub przycisk = OK")
          } else {
            Text("Sterowanie dotykiem")
          }
        }
        .font(.system(size: 9, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.5))
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Color.black.opacity(0.88))
    }
  }
}

// MARK: - Wiersz menu

struct TrikiFocusRow: View {
  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator

  let index: Int
  let title: String
  var subtitle: String?
  var accent: Color = NeonTheme.neonCyan
  var icon: String?

  private var isFocused: Bool {
    trikiUI.isConfigured && trikiUI.focusIndex == index
  }

  private var holdProgress: Double {
    isFocused ? trikiUI.holdProgress : 0
  }

  var body: some View {
    Button {
      trikiUI.activate(at: index)
    } label: {
      HStack(spacing: 12) {
        ZStack(alignment: .bottom) {
          Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 26, height: 40)
          Rectangle()
            .fill(accent)
            .frame(width: 26, height: 40 * holdProgress)
          if let icon {
            Image(systemName: icon)
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(isFocused ? .black : accent)
              .frame(width: 26, height: 40)
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.system(size: 14, weight: isFocused ? .heavy : .semibold, design: .monospaced))
            .foregroundStyle(isFocused ? accent : .white.opacity(0.88))
          if let subtitle {
            Text(subtitle)
              .font(.system(size: 10, design: .monospaced))
              .foregroundStyle(.white.opacity(0.45))
          }
        }
        Spacer()
        if isFocused {
          Image(systemName: motion.isTrikiControlAvailable ? "button.programmable" : "chevron.right")
            .foregroundStyle(accent)
            .font(.system(size: 12))
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 10)
      .background(isFocused ? accent.opacity(0.12) : Color.white.opacity(0.04))
      .overlay(
        RoundedRectangle(cornerRadius: 2)
          .stroke(isFocused ? accent.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
  }
}
