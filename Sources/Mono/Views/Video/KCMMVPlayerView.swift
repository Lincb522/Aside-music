import AVKit
import Combine
import SwiftUI

@MainActor
final class KCMMVPlayerViewModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellable: AnyCancellable?

    func load(hash: String, videoID: Int?) {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        cancellable?.cancel()
        cancellable = APIService.shared.fetchKugouMVURL(hash: hash, videoID: videoID)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] url in
                self?.videoURL = url
            })
    }
}

struct KCMMVPlayerView: View {
    let mv: KCMMV

    @StateObject private var viewModel = KCMMVPlayerViewModel()
    @State private var player: AVPlayer?
    @ObservedObject private var audioPlayer = PlayerManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ThemedPageBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                video

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            PlatformBadgeLabel(text: "KCM", source: .kugou, fontSize: 10)
                            if let date = mv.publishDate, !date.isEmpty {
                                Text(date)
                                    .font(.rounded(size: 12))
                                    .foregroundStyle(Color.monoTextSecondary)
                                    .lineLimit(1)
                            }
                        }

                        Text(mv.name)
                            .font(.rounded(size: 23, weight: .bold))
                            .foregroundStyle(Color.monoTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let artistName = mv.artistName, !artistName.isEmpty {
                            Text(artistName)
                                .font(.rounded(size: 14))
                                .foregroundStyle(Color.monoTextSecondary)
                        }

                        if let description = mv.description, !description.isEmpty {
                            Text(description)
                                .font(.rounded(size: 13))
                                .foregroundStyle(Color.monoTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
                    .padding(.top, 18)
                    .padding(.bottom, 60)
                }
                .scrollIndicators(.hidden)
                .themeRenderScrollLayer()
            }
        }
        .onAppear {
            audioPlayer.isTabBarHidden = true
            if audioPlayer.isPlaying { audioPlayer.togglePlayPause() }
            viewModel.load(hash: mv.hash, videoID: mv.videoID)
        }
        .onDisappear {
            player?.pause()
            audioPlayer.isTabBarHidden = false
        }
        .onChange(of: viewModel.videoURL) { _, url in
            guard let url else { return }
            let nextPlayer = AVPlayer(url: url)
            player = nextPlayer
            nextPlayer.play()
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                MonoIcon(icon: .close, size: 20, color: .monoTextPrimary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MonoBouncingButtonStyle())

            Spacer()

            Text("MV")
                .font(.rounded(size: 18, weight: .bold))
                .foregroundStyle(Color.monoTextPrimary)

            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, DeviceLayout.headerTopPadding)
    }

    private var video: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black)

            if let player {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 14) {
                    MonoIcon(icon: .warning, size: 30, color: .white.opacity(0.55))
                    Text(error)
                        .font(.rounded(size: 13))
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)
                    Button(String(localized: "radio_retry")) {
                        viewModel.load(hash: mv.hash, videoID: mv.videoID)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
            } else {
                ProgressView().tint(.white)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .padding(.horizontal, DeviceLayout.viewHorizontalPadding)
        .padding(.top, 4)
    }
}
