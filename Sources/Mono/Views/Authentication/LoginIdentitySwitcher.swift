import SwiftUI

@MainActor
struct LoginIdentitySwitcher: View {
    @ObservedObject private var identity = LoginIdentityManager.shared

    var body: some View {
        Menu {
            ForEach(LoginIdentityManager.supportedSources, id: \.rawValue) { source in
                Button {
                    guard identity.select(source) else { return }
                    HapticManager.shared.selection()
                } label: {
                    if identity.activeSource == source,
                       identity.isLoggedIn(to: source) {
                        Label(source.displayName, systemImage: "checkmark")
                    } else if identity.isLoggedIn(to: source) {
                        Text(source.displayName)
                    } else {
                        Label(
                            String.localizedStringWithFormat(
                                String(localized: "login_identity_not_signed_in_format"),
                                source.displayName
                            ),
                            systemImage: "person.crop.circle.badge.xmark"
                        )
                    }
                }
                .disabled(!identity.isLoggedIn(to: source))
            }
        } label: {
            HStack(spacing: 10) {
                if let source = identity.activeSource,
                   identity.isLoggedIn(to: source) {
                    PlatformBadgeLabel(
                        text: source.shortName,
                        source: source,
                        fontSize: 8
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("login_identity_current"))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.monoTextSecondary)

                        Text(source.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.monoTextPrimary)
                    }
                } else {
                    MonoIcon(icon: .personCircle, size: 18, color: .monoTextSecondary)

                    Text(LocalizedStringKey("login_identity_none"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.monoTextSecondary)
                }

                Spacer(minLength: 8)

                MonoIcon(icon: .chevronDown, size: 11, color: .monoTextSecondary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .themedPageSurface(cornerRadius: 16, elevated: false, mangaTint: MangaStyle.bubbleWhite)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityLabel(String(localized: "login_identity_switch_accessibility"))
        .accessibilityValue(
            identity.hasActiveIdentity
                ? identity.activeSource?.displayName ?? String(localized: "login_identity_none")
                : String(localized: "login_identity_none")
        )
        .accessibilityHint(String(localized: "login_identity_switch_hint"))
    }
}
