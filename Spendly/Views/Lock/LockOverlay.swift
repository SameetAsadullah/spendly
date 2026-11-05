import SwiftUI

/// Frosted cover over the blurred app while it is locked, and in the app switcher.
struct LockOverlay: View {
    var isUnlocked = false
    var failedAttempts = 0
    let onUnlock: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .headline) private var buttonIconSize: CGFloat = 22

    var body: some View {
        // At large text sizes the content can be taller than the screen, so it scrolls.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { background.ignoresSafeArea() }
        .accessibilityAddTraits(.isModal)
        .sensoryFeedback(.success, trigger: isUnlocked) { _, unlocked in unlocked }
        .sensoryFeedback(.error, trigger: failedAttempts) { old, new in new > old }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            message
            Spacer(minLength: 24)
            unlockControls
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 70)
    }

    @ViewBuilder
    private var background: some View {
        if reduceTransparency {
            Color(.systemGroupedBackground)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    colorScheme == .dark
                        ? Color.black.opacity(0.55)
                        : Color(red: 0.965, green: 0.965, blue: 0.976).opacity(0.65)
                )
        }
    }

    private var message: some View {
        VStack(spacing: 12) {
            lockSymbol
                .padding(.bottom, 10)
            Text("Spendly is locked")
                .font(.title.bold())
                .tracking(-0.2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 270)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: LocalizedStringKey {
        failedAttempts > 0
            ? "\(DeviceAuth.methodName) didn't match. Try again."
            : "Your numbers stay blurred until it's you."
    }

    private var lockSymbol: some View {
        Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(.primary)
            .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
            .symbolEffect(.bounce, value: reduceMotion ? 0 : failedAttempts)
            .frame(width: 84, height: 84)
            .background {
                Circle()
                    .fill(Color(.systemBackground).opacity(0.85))
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    .shadow(color: .black.opacity(0.12), radius: 15, y: 10)
            }
            .accessibilityHidden(true)
    }

    private var unlockControls: some View {
        VStack(spacing: 16) {
            Button(action: onUnlock) {
                Label {
                    Text("Unlock with \(DeviceAuth.methodName)")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: DeviceAuth.iconName)
                        .font(.system(size: buttonIconSize))
                }
                .font(.headline)
                .foregroundStyle(Color(.systemBackground))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56)
                // Matches a capsule at 56 pt, and stays a pill when large text wraps the label.
                .background(Color(.label), in: RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(colorScheme == .light ? 0.15 : 0), radius: 12, y: 10)
            }
            Text("Everything stays on this iPhone")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    /// Blurs the app behind the lock overlay and keeps it out of reach of touches and VoiceOver.
    func coveredByLock(_ isCovered: Bool) -> some View {
        blur(radius: isCovered ? 24 : 0, opaque: true)
            .allowsHitTesting(!isCovered)
            .accessibilityHidden(isCovered)
    }
}

#if DEBUG
private struct LockedOverviewPreview: View {
    var variant: PreviewVariant
    var failedAttempts = 0
    var reducesTransparency = false

    var body: some View {
        ZStack {
            DashboardView()
                .coveredByLock(true)
            LockOverlay(failedAttempts: failedAttempts) {}
        }
        .modelContainer(PreviewData.container)
        .defaultAppStorage(PreviewData.settings(monthlyBudget: 100_000))
        .environment(\._accessibilityReduceTransparency, reducesTransparency)
        .previewVariant(variant)
    }
}

#Preview("Locked · Light") { LockedOverviewPreview(variant: .light) }
#Preview("Locked · Dark") { LockedOverviewPreview(variant: .dark) }
#Preview("Locked · Accessibility 3") { LockedOverviewPreview(variant: .accessibility) }
#Preview("Locked · Reduce Transparency") { LockedOverviewPreview(variant: .light, reducesTransparency: true) }
#Preview("Failed attempt · Light") { LockedOverviewPreview(variant: .light, failedAttempts: 1) }
#Preview("Failed attempt · Dark") { LockedOverviewPreview(variant: .dark, failedAttempts: 1) }
#endif
