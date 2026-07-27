import SwiftUI

struct AppleMusicAccountView: View {
    @ObservedObject private var service = AppleMusicService.shared
    @State private var isRequestingAuthorization = false

    var body: some View {
        List {
            Section("授权") {
                HStack(spacing: 12) {
                    PlatformBadgeLabel(
                        text: MusicSource.appleMusic.shortName,
                        source: .appleMusic,
                        fontSize: 10
                    )

                    Text("Apple Music")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.monoTextPrimary)

                    Spacer()

                    Text(service.isAuthorized ? "已授权" : "未授权")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.monoTextSecondary)
                }
                .padding(.vertical, 4)
            }

            if !service.isAuthorized {
                Section {
                    Button {
                        requestAuthorization()
                    } label: {
                        if isRequestingAuthorization {
                            ProgressView()
                        } else {
                            Text("授权")
                        }
                    }
                    .disabled(isRequestingAuthorization)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemedPageBackground())
        .navigationTitle("Apple Music")
        .navigationBarTitleDisplayMode(.inline)
        .monoNavigationBackButton()
    }

    private func requestAuthorization() {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        Task { @MainActor in
            _ = await service.requestAuthorizationIfNeeded(refreshesSubscription: true)
            isRequestingAuthorization = false
        }
    }
}
