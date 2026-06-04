import SwiftUI
import VeltoKit

/// Shared Triki UI building blocks for screen wiring, HUD, and focus rows.
///
/// Use these components to enable consistent Triki interaction patterns on SwiftUI screens
/// that expose menu-like focus and activation behavior.

/// Triki UI surface helpers: screen modifier, HUD overlay and focus-aware row components.
///
/// Use these views/modifiers to add consistent Triki navigation behavior and affordances
/// across menu-like SwiftUI screens.

// MARK: - Ekran z nawigacją Triki

/// Applies Triki navigation loop and optional phone HUD to a screen.
struct TrikiUIScreenModifier: ViewModifier {
  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator

  /// Number of focusable items exposed by the screen.
  let itemCount: Int
  /// Enables or disables Triki handling for the current screen lifecycle.
  let isActive: Bool
  /// Controls whether phone-side HUD is rendered while Triki navigation is active.
  let showsPhoneHUD: Bool
  /// Ukrywa pasek hold — tylko podpowiedź „przycisk = OK” (quiz).
  let preferButtonConfirm: Bool
  /// Called when user confirms currently focused item.
  let onActivate: (Int) -> Void

  /// Wraps content with Triki update loop, safe-area HUD and activation lifecycle hooks.
  func body(content: Content) -> some View {
    let hudVisible = isActive && showsPhoneHUD && trikiUI.isConfigured && !trikiUI.isSuspended
    content
      .padding(.bottom, hudVisible ? TrikiUIConfig.bottomContentInset : 0)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if hudVisible {
          TrikiUIHUD(preferButtonConfirm: preferButtonConfirm)
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

  /// Re-initializes Triki navigation for the current screen context.
  private func activateScreen() {
    GameManager.applyUIMode(to: motion)
    trikiUI.isSuspended = false
    trikiUI.resetClock()
    trikiUI.configure(
      itemCount: itemCount,
      preferButtonConfirm: preferButtonConfirm,
      onActivate: onActivate
    )
  }
}

/// Opisuje extension `View` używany przez warstwę UI i logikę gry.
extension View {
  /// Triki screen modifier convenience entry points.
  ///
  /// Use these APIs on root containers of focusable screens to keep activation logic centralized.
  /// Attaches Triki screen behavior to any SwiftUI view.
  ///
  /// - Parameters:
  ///   - itemCount: Number of focusable items available on the screen.
  ///   - isActive: Whether Triki updates should run for this screen.
  ///   - showsPhoneHUD: Whether to render the bottom HUD on phone.
  ///   - onActivate: Action called on item confirmation.
  /// - Returns: A view decorated with Triki navigation and HUD overlays.
  ///
  /// Example:
  /// `menuView.trikiUIScreen(itemCount: 4) { index in select(index) }`
  func trikiUIScreen(
    itemCount: Int,
    isActive: Bool = true,
    showsPhoneHUD: Bool = true,
    preferButtonConfirm: Bool = false,
    onActivate: @escaping (Int) -> Void
  ) -> some View {
    modifier(
      TrikiUIScreenModifier(
        itemCount: itemCount,
        isActive: isActive,
        showsPhoneHUD: showsPhoneHUD,
        preferButtonConfirm: preferButtonConfirm,
        onActivate: onActivate
      )
    )
  }
}

// MARK: - HUD

/// Bottom overlay showing current Triki interaction status and hints.
struct TrikiUIHUD: View {
  var preferButtonConfirm: Bool = false

  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator

  /// Renders compact guidance for available control mode and hold progress.
  var body: some View {
    if trikiUI.isConfigured, !trikiUI.isSuspended {
      VStack(spacing: 6) {
        if motion.isTrikiControlAvailable {
          HStack(spacing: 8) {
            Image(systemName: preferButtonConfirm ? "button.programmable" : "arrow.left.and.right")
              .foregroundStyle(NeonTheme.neonCyan)
            Text(hudPrimaryHint)
              .font(.system(size: 10, weight: .bold, design: .monospaced))
            Spacer()
            if trikiUI.focusIndex != nil {
              Text("OK")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(NeonTheme.neonMagenta)
                .clipShape(Capsule())
            }
          }
          if !preferButtonConfirm {
            GeometryReader { geo in
              ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.12))
                Rectangle()
                  .fill(NeonTheme.neonMagenta)
                  .frame(width: geo.size.width * trikiUI.holdProgress)
              }
            }
            .frame(height: 4)
          }
        } else {
          HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
              .foregroundStyle(NeonTheme.neonMagenta)
            Text("Dotknij wiersz — od razu")
              .font(.system(size: 10, weight: .bold, design: .monospaced))
            Spacer()
          }
        }
        Text(hudSecondaryHint)
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.5))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(Color.black.opacity(0.88))
    }
  }

  private var hudPrimaryHint: String {
    if trikiUI.focusIndex == nil {
      return "Wyprostuj Triki — wybór"
    }
    return preferButtonConfirm ? "Przycisk Triki = potwierdź" : "Hold lub przycisk = OK"
  }

  private var hudSecondaryHint: String {
    if !motion.isTrikiControlAvailable { return "Sterowanie dotykiem" }
    return preferButtonConfirm
      ? "Obrót = wybór · przycisk = OK · dotyk też działa"
      : "Obrót = wybór · hold lub przycisk = OK"
  }
}

// MARK: - Wiersz menu

/// Single menu row with focus and hold feedback synchronized with Triki navigator.
struct TrikiFocusRow: View {
  @EnvironmentObject private var motion: MotionInputProvider
  @EnvironmentObject private var trikiUI: TrikiUINavigator

  /// Zero-based index used by navigator.
  let index: Int
  /// Primary row label.
  let title: String
  /// Optional secondary row label.
  var subtitle: String?
  /// Accent color used for focus visuals.
  var accent: Color = NeonTheme.neonCyan
  /// Optional SF Symbol rendered in row indicator.
  var icon: String?

  /// Whether this row is currently focused by Triki navigation.
  private var isFocused: Bool {
    trikiUI.isConfigured && trikiUI.focusIndex == index
  }

  /// Hold completion progress for this row in range `0...1`.
  private var holdProgress: Double {
    isFocused ? trikiUI.holdProgress : 0
  }

  /// Renders focus-aware row visuals and immediate touch activation behavior.
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
