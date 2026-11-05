import SwiftUI

/// Blurs the app and covers it with the lock overlay while it is locked, and in the app switcher,
/// when the app lock is on.
struct AppLockGate: ViewModifier {
    @AppStorage(AppSettings.appLockKey) private var isEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLocked = UserDefaults.standard.bool(forKey: AppSettings.appLockKey)
    @State private var isAuthenticating = false
    // The prompt itself makes the scene inactive, so only a return from the background prompts again.
    @State private var promptOnActive = false
    @State private var isUnlocked = false
    @State private var failedAttempts = 0

    private var isCovered: Bool {
        isEnabled && (isLocked || scenePhase != .active)
    }

    func body(content: Content) -> some View {
        ZStack {
            content
                .coveredByLock(isCovered)
            if isCovered {
                LockOverlay(isUnlocked: isUnlocked, failedAttempts: failedAttempts) {
                    Task { await unlock() }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if isEnabled {
                    isLocked = true
                    isUnlocked = false
                    failedAttempts = 0
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
        // The Face ID sheet keeps the scene inactive for a moment after a match. Leaving the app
        // before the reveal cancels it.
        .task(id: isUnlocked && scenePhase == .active) {
            if isUnlocked && scenePhase == .active {
                await reveal()
            }
        }
    }

    private func unlock() async {
        guard isEnabled, isLocked, !isAuthenticating, !isUnlocked else { return }
        // Without a passcode there is nothing to check against, and the app must not stay locked.
        guard DeviceAuth.isAvailable else {
            isLocked = false
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        guard await DeviceAuth.authenticate(reason: "Unlock Spendly to see your expenses.") else {
            // Leaving the app cancels the prompt, which is not a failed attempt.
            if !promptOnActive {
                withAnimation { failedAttempts += 1 }
            }
            return
        }
        withAnimation(.snappy) { isUnlocked = true }
    }

    /// Fades the overlay out once the app is active again, after a short look at the open lock.
    private func reveal() async {
        guard (try? await Task.sleep(for: .milliseconds(250))) != nil else { return }
        withAnimation(.easeOut(duration: 0.35)) {
            isLocked = false
        } completion: {
            isUnlocked = false
            failedAttempts = 0
        }
    }
}

extension View {
    func appLock() -> some View {
        modifier(AppLockGate())
    }
}
