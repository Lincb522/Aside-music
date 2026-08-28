import Foundation
import SwiftUI

// MARK: - 更新日志偏好键

enum ChangelogPreferenceKeys {
    /// 「新版本启动时自动弹出更新日志」开关
    static let autoPresent = "changelogAutoPresentEnabled"
    /// 最近一次已展示过更新日志的构建号
    static let lastSeenBuild = "changelogLastSeenBuild"
}

// MARK: - 数据模型

struct AppChangelogRelease: Codable, Identifiable, Equatable {
    let id: String
    let version: String
    let build: String
    let title: String
    let channel: String?
    let summary: String?
    let releaseNotes: String
    let publishedAt: String?
}

private struct AppChangelogResponse: Codable {
    let ok: Bool
    let latest: AppChangelogRelease?
    let releases: [AppChangelogRelease]?
}

// MARK: - 更新日志管理器

/// 版本更新后的首次启动拉取服务端更新日志并触发弹窗。
/// 数据源：主服务器 `/_admin/api/public/changelogs`（latest + releases）。
@MainActor
final class ChangelogManager: ObservableObject {
    static let shared = ChangelogManager()

    /// 待展示的版本记录；非空时 ContentView 弹出更新日志弹窗
    @Published var pendingRelease: AppChangelogRelease?

    private var didCheckThisLaunch = false
    private var pendingReleaseIsPreview = false

    private init() {}

    static var autoPresentEnabled: Bool {
        UserDefaults.standard.object(forKey: ChangelogPreferenceKeys.autoPresent) as? Bool ?? true
    }

    private var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    /// 启动后调用：仅当「本次构建号 ≠ 上次已展示的构建号」，
    /// 且服务端已发布**与当前构建号完全一致**的日志时才弹出。
    /// 当前版本的日志还没写（如装了 52 但服务端只有 50）就保持沉默、
    /// 不记录构建号，等日志发布后的下一次启动再弹。
    func presentLatestAfterUpdateIfNeeded() {
        guard !didCheckThisLaunch else { return }
        didCheckThisLaunch = true

        guard Self.autoPresentEnabled else { return }

        let build = currentBuild
        guard UserDefaults.standard.string(forKey: ChangelogPreferenceKeys.lastSeenBuild) != build else {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            guard let release = await self.fetchRelease(exactBuild: build) else { return }

            let notes = release.releaseNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !notes.isEmpty else { return }

            // 等主界面从欢迎页切换完成后再弹，避免与首帧动画抢镜
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.pendingReleaseIsPreview = false
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                self.pendingRelease = release
            }
        }
    }

    func dismissPendingRelease() {
        if !pendingReleaseIsPreview {
            UserDefaults.standard.set(currentBuild, forKey: ChangelogPreferenceKeys.lastSeenBuild)
        }
        pendingReleaseIsPreview = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.92)) {
            pendingRelease = nil
        }
    }

    /// 开发者弹窗预览；关闭时不写入正式版本的已读状态。
    func presentPreview(_ release: AppChangelogRelease) {
        pendingReleaseIsPreview = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            pendingRelease = release
        }
    }

    /// 历史更新日志（关于页 → 更新日志页面用）：从新到旧排列。
    /// 服务端存在非数字 build（历史脏数据），排序以发布时间为准、构建号兜底。
    func fetchAllReleases() async -> [AppChangelogRelease]? {
        guard let payload = await fetchPayload() else { return nil }
        var releases = payload.releases ?? []
        if let latest = payload.latest, !releases.contains(where: { $0.id == latest.id }) {
            releases.append(latest)
        }
        return releases.sorted { lhs, rhs in
            switch (lhs.publishedAt, rhs.publishedAt) {
            case let (l?, r?) where l != r:
                return l > r
            default:
                return (Int(lhs.build) ?? 0) > (Int(rhs.build) ?? 0)
            }
        }
    }

    /// 只认与当前构建号完全一致的记录 —— 服务端还没写这版的日志就返回 nil，
    /// 绝不回退展示旧版本的日志。
    private func fetchRelease(exactBuild build: String) async -> AppChangelogRelease? {
        guard let payload = await fetchPayload() else { return nil }

        let target = build.trimmingCharacters(in: .whitespaces)
        let releases = payload.releases ?? []
        if let exact = releases.first(where: {
            $0.build.trimmingCharacters(in: .whitespaces) == target
        }) {
            return exact
        }
        if let latest = payload.latest,
           latest.build.trimmingCharacters(in: .whitespaces) == target {
            return latest
        }
        AppLogger.info("[Changelog] 服务端暂无 build \(build) 的更新日志，跳过弹窗")
        return nil
    }

    private func fetchPayload() async -> AppChangelogResponse? {
        guard var components = URLComponents(string: SecureConfig.apiBaseURL(for: .primary)) else {
            return nil
        }
        let route = "/_admin/api/public/changelogs"
        components.path = components.path.hasSuffix("/")
            ? "\(components.path)\(route.dropFirst())"
            : "\(components.path)\(route)"
        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let payload = try? JSONDecoder().decode(AppChangelogResponse.self, from: data),
              payload.ok else {
            AppLogger.error("[Changelog] 更新日志拉取失败")
            return nil
        }
        return payload
    }
}
