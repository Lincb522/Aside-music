#if os(macOS)
import SwiftUI

struct MacSearchOverlay: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = SearchViewModel()
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedArtistId: Int?
    @State private var selectedPlaylist: Playlist?
    @State private var selectedAlbumId: Int?

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                if viewModel.query.isEmpty {
                    emptyStateView
                } else {
                    resultsView
                }
            }
            .frame(maxWidth: 640, maxHeight: 520)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onExitCommand { close() }
    }

    private func close() {
        withAnimation { isPresented = false }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField(String(localized: "search_placeholder"), text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .focused($isFocused)
                .onSubmit {
                    viewModel.performSearch(keyword: viewModel.query)
                }

            if !viewModel.query.isEmpty {
                Button(action: { viewModel.query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            Button(action: close) {
                Text("ESC")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    // MARK: - Empty

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            if !viewModel.hotSearchItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "hot_search"))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .tracking(0.5)

                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.hotSearchItems.prefix(12)) { item in
                            Button(action: {
                                viewModel.query = item.searchWord
                                viewModel.performSearch(keyword: item.searchWord)
                            }) {
                                Text(item.searchWord)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color.primary.opacity(0.05))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !viewModel.neteaseResults.isEmpty {
                    searchResultSection(title: String(localized: "歌曲")) {
                        ForEach(Array(viewModel.neteaseResults.prefix(8).enumerated()), id: \.element.id) { idx, song in
                            MacSongRow(song: song, index: idx + 1) {
                                PlayerManager.shared.play(song: song, in: viewModel.neteaseResults)
                            }
                        }
                    }
                }

                if !viewModel.qqResults.isEmpty {
                    searchResultSection(title: "QCM") {
                        ForEach(Array(viewModel.qqResults.prefix(6).enumerated()), id: \.element.id) { idx, song in
                            MacSongRow(song: song, index: idx + 1) {
                                PlayerManager.shared.play(song: song, in: viewModel.qqResults)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private func searchResultSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            content()
        }
    }
}

#endif
