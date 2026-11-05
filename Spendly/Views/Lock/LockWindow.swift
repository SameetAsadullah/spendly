import SwiftUI
import UIKit

/// Shows the lock overlay in its own window above the app. Sheets and alerts live in the app's
/// window, so an overlay inside it would leave them uncovered.
@MainActor
@Observable
final class LockWindow {
    var isUnlocked = false
    var failedAttempts = 0
    fileprivate var isShowing = false
    @ObservationIgnored fileprivate var onUnlock: () -> Void = {}
    @ObservationIgnored private var window: UIWindow?

    func show(onUnlock: @escaping () -> Void) {
        self.onUnlock = onUnlock
        isShowing = true
        guard let window = window ?? makeWindow() else { return }
        window.isHidden = false
        setAppHiddenFromVoiceOver(true)
    }

    func hide() {
        guard isShowing else { return }
        setAppHiddenFromVoiceOver(false)
        withAnimation(.easeOut(duration: 0.35)) {
            isShowing = false
        } completion: { [weak self] in
            // The app can lock again during the fade.
            guard let self, !self.isShowing else { return }
            window?.isHidden = true
            isUnlocked = false
            failedAttempts = 0
        }
    }

    private func makeWindow() -> UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return nil }
        let host = UIHostingController(rootView: LockWindowRoot(lock: self))
        host.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.windowLevel = .alert + 1
        self.window = window
        return window
    }

    private func setAppHiddenFromVoiceOver(_ hidden: Bool) {
        for appWindow in window?.windowScene?.windows ?? [] where appWindow !== window {
            appWindow.accessibilityElementsHidden = hidden
        }
    }
}

private struct LockWindowRoot: View {
    let lock: LockWindow
    // The app applies this to its own window only.
    @AppStorage(AppSettings.appearanceKey) private var appearance: Appearance = .system

    var body: some View {
        ZStack {
            if lock.isShowing {
                LockOverlay(
                    isUnlocked: lock.isUnlocked,
                    failedAttempts: lock.failedAttempts,
                    onUnlock: lock.onUnlock
                )
                .transition(.opacity)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}
