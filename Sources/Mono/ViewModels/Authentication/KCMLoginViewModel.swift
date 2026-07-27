import SwiftUI

@MainActor
final class KCMLoginViewModel: ObservableObject {
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage = "加载二维码中..."
    @Published var isQRExpired = false
    @Published var isLoggedIn = false

    private let service: KCMMusicService
    private var pollTask: Task<Void, Never>?
    private var currentKey: String?

    init(service: KCMMusicService = .shared) {
        self.service = service
    }

    func startQRLogin() {
        stopPolling()
        qrCodeImage = nil
        isQRExpired = false
        isLoggedIn = false
        qrStatusMessage = "加载二维码中..."

        pollTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await service.createQRCode()
                guard !Task.isCancelled else { return }
                currentKey = session.key
                qrCodeImage = UIImage(data: session.imageData)
                qrStatusMessage = "等待扫码"
                await poll(key: session.key)
            } catch {
                guard !Task.isCancelled else { return }
                qrStatusMessage = error.localizedDescription
            }
        }
    }

    func refreshQR() {
        startQRLogin()
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        currentKey = nil
    }

    private func poll(key: String) async {
        while !Task.isCancelled, currentKey == key {
            do {
                let status = try await service.checkQRCode(key: key)
                guard !Task.isCancelled else { return }
                switch status {
                case .expired:
                    qrStatusMessage = "二维码已过期"
                    isQRExpired = true
                    return
                case .waiting:
                    qrStatusMessage = "等待扫码"
                case .scanned:
                    qrStatusMessage = "已扫码，请在手机上确认"
                case .confirmed:
                    qrStatusMessage = "登录成功"
                    isLoggedIn = true
                    return
                }
            } catch {
                guard !Task.isCancelled else { return }
                qrStatusMessage = error.localizedDescription
            }

            do {
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                return
            }
        }
    }

    deinit {
        pollTask?.cancel()
    }
}
