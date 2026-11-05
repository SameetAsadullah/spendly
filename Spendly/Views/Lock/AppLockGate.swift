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
    @State private var lockWindow = LockWindow()
    // The Face ID sheet keeps the scene inactive for about a second after a match. That must not
    // hold the overlay up, so it can fade at once.
    @State private var isLeavingPrompt = false

    private var isCovered: Bool {
        isEnabled && (isLocked || (scenePhase != .active && !isLeavingPrompt))
    }

    func body(content: Content) -> some View {
        content
            .coveredByLock(isCovered)
            .onChange(of: isCovered, initial: true) { _, covered in
                if covered {
                    lockWindow.show { Task { await unlock() } }
                } else {
                    lockWindow.hide()
                }
            }
            // Also clears it when the scene is already active, so the app switcher covers the app again.
            .onChange(of: isLeavingPrompt && scenePhase != .inactive) { _, isDone in
                if isDone {
                    isLeavingPrompt = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    if isEnabled {
                        isLocked = true
                        lockWindow.isUnlocked = false
                        lockWindow.failedAttempts = 0
                        promptOnActive = true
                        // The keyboard has its own window above the lock.
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                        )
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
            // Leaving the app before the reveal cancels it.
            .task(id: lockWindow.isUnlocked) {
                if lockWindow.isUnlocked {
                    await reveal()
                }
            }
    }

    private func unlock() async {
        guard isEnabled, isLocked, !isAuthenticating, !lockWindow.isUnlocked else { return }
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
                withAnimation { lockWindow.failedAttempts += 1 }
            }
            return
        }
        isLeavingPrompt = true
        withAnimation(.snappy) { lockWindow.isUnlocked = true }
    }

    /// Fades the overlay out after a short look at the open lock.
    private func reveal() async {
        guard (try? await Task.sleep(for: .milliseconds(250))) != nil else { return }
        withAnimation(.easeOut(duration: 0.35)) {
            isLocked = false
        }
    }
}

extension View {
    func appLock() -> some View {
        modifier(AppLockGate())
    }
}
