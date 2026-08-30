import SwiftUI

@MainActor
final class KCMLoginViewModel: ObservableObject {
    @Published var qrCodeImage: UIImage?
    @Published var qrStatusMessage = String(localized: "qr_loading")
    @Published var isQRExpired = false
    @Published var isLoggedIn = false

    private let service: KCMMusicService
    private var pollTask: Task<Void, Never>?
    private var currentKey: String?
    private var currentAttempt: KCMMusicService.LoginAttempt?

    init(service: KCMMusicService = .shared) {
        self.service = service
    }

    func startQRLogin() {
        stopPolling()
        qrCodeImage = nil
        isQRExpired = false
        isLoggedIn = false
        qrStatusMessage = String(localized: "qr_loading")
        let attempt = service.beginLoginAttempt()
        currentAttempt = attempt

        pollTask = Task { [weak self] in
            guard let self else { return }
            do {
                let session = try await service.createQRCode(for: attempt)
                guard !Task.isCancelled,
                      currentAttempt == attempt,
                      service.isCurrentLoginAttempt(attempt) else { return }
                currentKey = session.key
                qrCodeImage = UIImage(data: session.imageData)
                qrStatusMessage = String(localized: "qr_waiting")
                await poll(key: session.key, attempt: attempt)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, currentAttempt == attempt else { return }
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
        if let currentAttempt {
            service.cancelLoginAttempt(currentAttempt)
        }
        currentAttempt = nil
        currentKey = nil
    }

    private func poll(key: String, attempt: KCMMusicService.LoginAttempt) async {
        while !Task.isCancelled, currentKey == key, currentAttempt == attempt {
            do {
                let status = try await service.checkQRCode(key: key, for: attempt)
                guard !Task.isCancelled,
                      currentKey == key,
                      currentAttempt == attempt else { return }
                switch status {
                case .expired:
                    qrStatusMessage = String(localized: "qr_expired")
                    isQRExpired = true
                    service.cancelLoginAttempt(attempt)
                    currentAttempt = nil
                    currentKey = nil
                    return
                case .waiting:
                    qrStatusMessage = String(localized: "qr_waiting")
                case .scanned:
                    qrStatusMessage = String(localized: "qr_scanned")
                case .confirmed:
                    qrStatusMessage = String(localized: "login_success")
                    isLoggedIn = true
                    currentAttempt = nil
                    currentKey = nil
                    return
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled,
                      currentKey == key,
                      currentAttempt == attempt else { return }
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
        if let currentAttempt {
            service.cancelLoginAttempt(currentAttempt)
        }
    }
}
