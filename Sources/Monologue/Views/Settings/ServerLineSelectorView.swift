// 设置页线路选择：自动 / 主线路 / 备用线路
// 仅在构建配置了备用线路时显示

import SwiftUI

struct ServerLineSelectorView: View {
    @ObservedObject private var lineManager = ServerLineManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                MonologueIcon(icon: .cloud, size: 14, color: statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "settings_server_line_title"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.monologueTextPrimary)

                    Text(statusText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.monologueTextSecondary)
                }

                Spacer()

                if lineManager.isProbing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            HStack(spacing: 8) {
                ForEach(availableOptions, id: \.rawValue) { option in
                    optionButton(option)
                }
            }
        }
    }

    private var availableOptions: [ServerLinePreference] {
        ServerLinePreference.allCases.filter { option in
            switch option {
            case .auto, .primary:
                return true
            case .backup:
                return ServerLineManager.isFirstBackupConfigured
            case .backup2:
                return ServerLineManager.isSecondBackupConfigured
            }
        }
    }

    private func optionButton(_ option: ServerLinePreference) -> some View {
        let isSelected = lineManager.preference == option
        return Button {
            guard lineManager.preference != option else { return }
            HapticManager.shared.selection()
            lineManager.setPreference(option)
        } label: {
            Text(optionTitle(option))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? Color(light: .white, dark: .black) : .monologueTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.monologueAccent : Color.monologueSeparator.opacity(0.32))
                )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.95))
    }

    private func optionTitle(_ option: ServerLinePreference) -> String {
        switch option {
        case .auto: return String(localized: "server_line_auto")
        case .primary: return ServerLine.primary.displayName
        case .backup: return ServerLine.backup.displayName
        case .backup2: return ServerLine.backup2.displayName
        }
    }

    private var statusText: String {
        let active = lineManager.activeLine
        var text = String(format: String(localized: "server_line_current_format"), active.displayName)
        if let probe = lineManager.probeResults[active] {
            if let latency = probe.latency {
                text += String(format: " · %.0fms", latency * 1000)
            } else {
                text += " · " + String(localized: "server_line_unreachable")
            }
        }
        return text
    }

    private var statusColor: Color {
        guard let probe = lineManager.probeResults[lineManager.activeLine] else {
            return .monologueTextSecondary
        }
        return probe.isAlive ? .green : .red
    }
}
