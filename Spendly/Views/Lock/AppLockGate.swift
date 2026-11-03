import SwiftUI

/// Covers the app while it is locked, and in the app switcher, when the app lock is on.
struct AppLockGate: ViewModifier {
    @AppStorage(AppSettings.appLockKey) private var isEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = UserDefaults.standard.bool(forKey: AppSettings.appLockKey)
    @State private var isAuthenticating = false
    // The prompt itself makes the scene inactive, so only a return from the background prompts again.
    @State private var promptOnActive = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isEnabled && (isLocked || scenePhase != .active) {
                    LockScreen(showsUnlockButton: isLocked && !isAuthenticating) {
                        Task { await unlock() }
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if isEnabled {
                        isLocked = true
                        promptOnActive = true
                    }
                case .active:
                    if promptOnActive {
                        promptOnActive = false
                        Task { await unlock() }
                    }
                default:
                    break
                }
            }
            .task {
                await unlock()
            }
    }

    private func unlock() async {
        guard isEnabled, isLocked, !isAuthenticating else { return }
        // Without a passcode there is nothing to check against, and the app must not stay locked.
        guard DeviceAuth.isAvailable else {
            isLocked = false
            return
        }
        isAuthenticating = true
        if await DeviceAuth.authenticate(reason: "Unlock Spendly to see your expenses.") {
            isLocked = false
        }
        isAuthenticating = false
    }
}

private struct LockScreen: View {
    let showsUnlockButton: Bool
    let unlock: () -> Void

    var body: some View {
        ZStack {
            Theme.heroGradient
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 320, height: 320)
                .offset(x: 110, y: -110)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 260, height: 260)
                .offset(x: -90, y: 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle.weight(.semibold))
                    .frame(width: 96, height: 96)
                    .background(
                        .white.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.icon(96), style: .continuous)
                    )
                    .padding(.bottom, 10)
                    .accessibilityHidden(true)
                Text("Spendly is locked")
                    .font(.title2.bold())
                Text("Your expenses stay on this device. Unlock to see them.")
                    .font(.subheadline)
                    .opacity(0.85)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.hero)
        }
        .clipped()
        .foregroundStyle(.white)
        .overlay(alignment: .bottom) {
            if showsUnlockButton {
                Button(action: unlock) {
                    Label("Unlock with \(DeviceAuth.methodName)", systemImage: DeviceAuth.iconName)
                        .font(.headline)
                        .foregroundStyle(Theme.brand)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(.white, in: Capsule())
                }
                .padding(.horizontal, Theme.Spacing.hero)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview("Lock, light") {
    LockScreen(showsUnlockButton: true) {}.previewVariant(.light)
}

#Preview("Lock, dark") {
    LockScreen(showsUnlockButton: true) {}.previewVariant(.dark)
}

#Preview("Lock, accessibility3") {
    LockScreen(showsUnlockButton: true) {}.previewVariant(.accessibility)
}
#endif

extension View {
    func appLock() -> some View {
        modifier(AppLockGate())
    }
}
