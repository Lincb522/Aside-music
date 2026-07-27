import SwiftUI

/// 听歌统计页中的 AI 洞察卡片：按 `agent.phase` 在
/// 触发按钮 / 分析中 / 结果展示 / 失败重试 四种状态间切换，输入变化时自动复位。
struct AIListeningInsightSection: View {
    @ObservedObject var agent: AIListeningInsightAgent
    let input: AIListeningInsightInput

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch agent.phase {
            case .idle:
                analyzeButton
            case .requesting:
                requestingState
            case .ready:
                if let result = agent.result {
                    resultContent(result)
                } else {
                    analyzeButton
                }
            case let .failed(message):
                failureState(message)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.monoAccent.opacity(0.065))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.monoAccent.opacity(0.14), lineWidth: 1)
        }
        .onAppear { agent.prepare(for: input) }
        .onChange(of: input.cacheKey) { _, _ in agent.prepare(for: input) }
    }

    private var header: some View {
        HStack(spacing: 9) {
            MonoIcon(icon: .sparkle, size: 15, color: .monoAccent)
            Text(String(localized: "ai_listening_title"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.monoTextPrimary)

            Spacer()

            if agent.phase == .ready, agent.result != nil {
                Button { agent.analyze(input, force: true) } label: {
                    MonoIcon(icon: .refresh, size: 13, color: .monoTextSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.monoTextPrimary.opacity(0.055)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "ai_listening_refresh"))
            } else if agent.phase.isWorking {
                Button(action: agent.cancel) {
                    MonoIcon(icon: .close, size: 11, color: .monoTextSecondary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.monoTextPrimary.opacity(0.055)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "ai_lab_cancel"))
            }
        }
    }

    private var analyzeButton: some View {
        Button { agent.analyze(input) } label: {
            HStack(spacing: 8) {
                Text(String(localized: "ai_listening_analyze"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                MonoIcon(icon: .chevronRight, size: 11, color: .monoAccent)
            }
            .foregroundStyle(Color.monoAccent)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var requestingState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(.monoAccent)
            Text(String(localized: "ai_listening_analyzing"))
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)
            Spacer()
        }
        .frame(height: 34)
    }

    private func resultContent(_ result: AIListeningInsightResult) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(result.headline)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.monoTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(result.summary)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(Color.monoTextPrimary.opacity(0.08))
                .frame(height: 0.5)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(result.observations.enumerated()), id: \.offset) { _, observation in
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Circle()
                            .fill(Color.monoAccent)
                            .frame(width: 5, height: 5)
                        Text(observation)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.monoTextPrimary.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func failureState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.monoTextSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button { agent.analyze(input, force: true) } label: {
                Text(String(localized: "ai_listening_retry"))
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.monoAccent)
            }
            .buttonStyle(.plain)
        }
    }
}
