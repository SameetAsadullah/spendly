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
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44, weight: .semibold))
                Text("Spendly is locked")
                    .font(.title2.weight(.bold))
                if showsUnlockButton {
                    Button(action: unlock) {
                        Label("Unlock with \(DeviceAuth.methodName)", systemImage: DeviceAuth.iconName)
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.2), in: Capsule())
                    }
                }
            }
            .foregroundStyle(.white)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func appLock() -> some View {
        modifier(AppLockGate())
    }
}
