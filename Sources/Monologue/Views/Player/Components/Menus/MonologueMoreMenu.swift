import SwiftUI

// MARK: - Unified ellipsis menu components

struct MonologueMoreMenuOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    var isDarkBackground = false
    var topPadding: CGFloat = 8
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(292, max(240, proxy.size.width - 24))

            ZStack(alignment: .topTrailing) {
                Color.black.opacity(isDarkBackground ? 0.07 : 0.035)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: close)

                MonologueMoreMenuPanel(
                    title: title,
                    isDarkBackground: isDarkBackground,
                    closeAction: close
                ) {
                    content()
                }
                .frame(width: panelWidth)
                .padding(.top, topPadding)
                .padding(.trailing, 12)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
            }
        }
        .accessibilityAction(.escape, close)
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.18)) {
            isPresented = false
        }
    }
}

struct MonologueMoreMenuPanel<Content: View>: View {
    let title: String
    var isDarkBackground = false
    let closeAction: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)

                Spacer(minLength: 0)

                Button(action: closeAction) {
                    MonologueIcon(icon: .close, size: 12, color: .monologueTextSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.monologueTextPrimary.opacity(0.055)))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "common_close"))
            }
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .padding(.vertical, 4)

            Rectangle()
                .fill(Color.monologueSeparator)
                .frame(height: 0.5)

            content()
                .padding(12)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.monologueGlassTint)
                .monologueGlass(cornerRadius: 16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(isDarkBackground ? 0.3 : 0.2), radius: 12, x: 0, y: 6)
    }
}

struct MonologueMoreMenuSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(.monologueTextSecondary)
                .padding(.horizontal, 4)

            content()
        }
    }
}

struct MonologueMoreMenuGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.monologueTextPrimary.opacity(0.04))
        )
    }
}

struct MonologueMoreMenuRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    var trailingText: String? = nil
    var isDestructive = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                rowIcon

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(rowColor.opacity(isEnabled ? 1 : 0.36))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let trailingText, !trailingText.isEmpty {
                    Text(trailingText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary.opacity(isEnabled ? 1 : 0.36))
                        .lineLimit(1)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var rowColor: Color {
        isDestructive ? .red : .monologueTextPrimary
    }

    private var rowIcon: some View {
        MonologueIcon(icon: icon, size: 16, color: rowColor.opacity(0.82))
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(rowColor.opacity(isDestructive ? 0.1 : 0.045))
            )
    }
}

struct MonologueMoreMenuToggleRow: View {
    let icon: MonologueIcon.IconType
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn.animation(.easeOut(duration: 0.18))) {
            HStack(spacing: 11) {
                MonologueIcon(
                    icon: icon,
                    size: 16,
                    color: isOn ? .monologueAccent : .monologueTextPrimary.opacity(0.82)
                )
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            isOn
                                ? Color.monologueAccent.opacity(0.12)
                                : Color.monologueTextPrimary.opacity(0.045)
                        )
                )

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.monologueTextPrimary)
                    .lineLimit(1)
            }
        }
        .tint(.monologueAccent)
        .padding(.horizontal, 12)
        .frame(minHeight: 46)
    }
}

struct MonologueMoreMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.monologueSeparator)
            .frame(height: 0.5)
            .padding(.leading, 53)
    }
}
