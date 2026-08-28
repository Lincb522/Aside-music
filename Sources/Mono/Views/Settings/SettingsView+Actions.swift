import SwiftUI

extension SettingsView {
    // MARK: - Actions

    /// 提交并校验 API Token（aside 名片与其他主题卡片共用）
    func submitAPIToken() {
        let trimmed = apiTokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        apiTokenInput = trimmed

        Task {
            let outcome = await onlineAccess.submitToken(trimmed)

            await MainActor.run {
                switch outcome {
                case .agreementRequired:
                    isShowingTokenAgreement = true
                case let .status(status):
                    handleTokenSubmissionStatus(status, submittedToken: trimmed)
                }
            }
        }
    }

    func acceptPendingTokenAuthorization() {
        guard let status = onlineAccess.acceptPendingTokenAuthorization() else { return }
        isShowingTokenAgreement = false
        handleTokenSubmissionStatus(status, submittedToken: apiTokenInput)
    }

    func declinePendingTokenAuthorization() {
        onlineAccess.declinePendingTokenAuthorization()
        isShowingTokenAgreement = false
    }

    func handleTokenSubmissionStatus(_ status: APIService.TokenStatus, submittedToken: String) {
        switch status {
        case .valid, .validationDisabled:
            HapticManager.shared.success()
            tokenSaved = !submittedToken.isEmpty
            isHeaderCardExpanded = submittedToken.isEmpty

            if tokenSaved {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { tokenSaved = false }
                }
            }
        case .missing:
            tokenSaved = false
            isHeaderCardExpanded = true
        case .invalid:
            AlertManager.shared.show(
                title: settingsText("access_invalid_title"),
                message: settingsText("access_invalid_message"),
                primaryButtonTitle: settingsText("common_ok"),
                primaryAction: {}
            )
        case .expired:
            AlertManager.shared.show(
                title: String(localized: "Token 已过期"),
                message: String(localized: "您输入的 Token 已经过期，请获取新的 Token 或者重新授权。"),
                primaryButtonTitle: settingsText("common_ok"),
                primaryAction: {}
            )
        case .deviceMismatch:
            AlertManager.shared.show(
                title: String(localized: "设备不匹配"),
                message: String(localized: "此 Token 已绑定到其他设备，无法在当前设备使用。"),
                primaryButtonTitle: settingsText("common_ok"),
                primaryAction: {}
            )
        case .networkError:
            AlertManager.shared.show(
                title: settingsText("access_network_error_title"),
                message: settingsText("access_network_error_message"),
                primaryButtonTitle: settingsText("common_ok"),
                primaryAction: {}
            )
        }
    }

    func updateCacheSize() {
        Task {
            let cacheTotal = await Task.detached(priority: .utility) {
                let fm = FileManager.default
                var total: Int64 = 0

                if let cacheBase = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let cacheDir = cacheBase.appendingPathComponent("MonoCache")
                    if let files = try? fm.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.totalFileAllocatedSizeKey], options: .skipsHiddenFiles) {
                        for file in files {
                            total += Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]))?.totalFileAllocatedSize ?? 0)
                        }
                    }
                }

                if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    let dbPath = appSupport.appendingPathComponent("default.store").path
                    for ext in ["", ".wal", ".shm"] {
                        let path = ext.isEmpty ? dbPath : dbPath + ext
                        if let attrs = try? fm.attributesOfItem(atPath: path), let size = attrs[.size] as? Int64 {
                            total += size
                        }
                    }
                }

                return total
            }.value

            let total = cacheTotal + DownloadManager.shared.totalDownloadSize()

            let formattedSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)

            cacheSize = formattedSize
        }
    }

    func clearCache() {
        MonoMemoryEngine.shared.trim(level: .critical, reason: .manual)
        OptimizedCacheManager.shared.clearAll()
        CacheManager.shared.clearAll()
        CachedAsyncImage<EmptyView>.clearMemoryCache()
        URLCache.shared.removeAllCachedResponses()
        updateCacheSize()
    }
}
