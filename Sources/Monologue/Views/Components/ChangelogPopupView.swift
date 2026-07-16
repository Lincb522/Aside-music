import SwiftUI

// MARK: - 更新日志弹窗覆盖层

/// 挂在主界面最上层；`ChangelogManager.pendingRelease` 非空时弹出。
struct ChangelogPopupOverlay: View {
    @ObservedObject private var manager = ChangelogManager.shared

    var body: some View {
        ZStack {
            if let release = manager.pendingRelease {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { manager.dismissPendingRelease() }

                ChangelogPopupCard(release: release) {
                    manager.dismissPendingRelease()
                }
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.88).combined(with: .opacity),
                        removal: .scale(scale: 0.96).combined(with: .opacity)
                    )
                )
            }
        }
        .animation(
            .spring(response: 0.42, dampingFraction: 0.86),
            value: manager.pendingRelease?.id
        )
    }
}

// MARK: - 弹窗卡片

private struct ChangelogPopupCard: View {
    let release: AppChangelogRelease
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var sections: [ChangelogNoteSection] {
        ChangelogNotesParser.parse(release.releaseNotes)
    }

    private var versionText: String {
        release.version.isEmpty ? release.build : release.version
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sections) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
            .frame(maxHeight: min(420, UIScreen.main.bounds.height * 0.46))
            .mask(
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 22)
                }
            )

            footer
        }
        .frame(maxWidth: 348)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.5), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.28), radius: 40, x: 0, y: 18)
        .padding(.horizontal, 28)
    }

    // MARK: 头部

    private var header: some View {
        ZStack(alignment: .topLeading) {
            // 顶部主题色光带：主色 → 透明，叠一颗高光泡
            LinearGradient(
                colors: [
                    Color.monologueAccent.opacity(colorScheme == .dark ? 0.34 : 0.2),
                    Color.monologueAccent.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.monologueAccent.opacity(colorScheme == .dark ? 0.3 : 0.18))
                .frame(width: 130, height: 130)
                .blur(radius: 46)
                .offset(x: -30, y: -58)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    HStack(spacing: 5) {
                        MonologueIcon(icon: .sparkle, size: 11, color: .monologueAccent)
                        Text(String(localized: "新版本"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.monologueAccent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.monologueAccent.opacity(0.14))
                            .overlay(
                                Capsule().stroke(Color.monologueAccent.opacity(0.3), lineWidth: 0.8)
                            )
                    )

                    Spacer()

                    Button(action: onDismiss) {
                        MonologueIcon(icon: .close, size: 11, color: .monologueTextSecondary)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.monologueSeparator.opacity(0.4)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(MonologueBouncingButtonStyle(scale: 0.88))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "更新内容"))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text("Version \(versionText)")
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.monologueTextSecondary)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: 内容区

    private func sectionBlock(_ section: ChangelogNoteSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = section.title {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(sectionTint(title))
                        .frame(width: 4, height: 13)

                    Text(title)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(sectionTint(section.title).opacity(0.85))
                            .frame(width: 4.5, height: 4.5)
                            .padding(.top, 6.5)

                        Text(item)
                            .font(.system(size: 13.5, weight: .regular, design: .rounded))
                            .foregroundColor(.monologueTextPrimary.opacity(0.84))
                            .lineSpacing(3.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func sectionTint(_ title: String?) -> Color {
        switch title {
        case "新增": return .green
        case "优化": return .blue
        case "修复": return .orange
        default: return .monologueAccent
        }
    }

    // MARK: 底部

    private var footer: some View {
        Button(action: onDismiss) {
            Text(String(localized: "知道了"))
                .font(.system(size: 15.5, weight: .bold, design: .rounded))
                .foregroundColor(Color(light: .white, dark: .black))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.monologueAccent)
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.97))
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 20)
    }

    private var cardBackground: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            Rectangle().fill(Color.monologueGlassTint.opacity(0.5))
        }
    }
}

// MARK: - 更新说明解析

struct ChangelogNoteSection: Identifiable {
    let id: Int
    let title: String?
    let items: [String]
}

/// 服务端 releaseNotes 是纯文本：
/// 「新增 / 优化 / 修复」等短行为分组标题，「• / · / -」开头的行为条目。
enum ChangelogNotesParser {
    static func parse(_ raw: String) -> [ChangelogNoteSection] {
        var sections: [ChangelogNoteSection] = []
        var currentTitle: String?
        var currentItems: [String] = []

        func flush() {
            guard currentTitle != nil || !currentItems.isEmpty else { return }
            sections.append(
                ChangelogNoteSection(id: sections.count, title: currentTitle, items: currentItems)
            )
            currentTitle = nil
            currentItems = []
        }

        for rawLine in raw.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if let item = strippedBulletItem(line) {
                if !item.isEmpty {
                    currentItems.append(item)
                }
                continue
            }

            // 无符号短行视作分组标题；长行并入当前分组条目
            if line.count <= 8 {
                flush()
                currentTitle = line
            } else {
                currentItems.append(line)
            }
        }
        flush()
        return sections
    }

    private static func strippedBulletItem(_ line: String) -> String? {
        let bullets: [Character] = ["•", "·", "‣", "◦", "*", "-"]
        guard let first = line.first, bullets.contains(first) else { return nil }
        return String(line.dropFirst())
            .trimmingCharacters(in: .whitespaces)
    }
}
