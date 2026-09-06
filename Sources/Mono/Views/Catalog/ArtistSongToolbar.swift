import SwiftUI

struct ArtistSongToolbar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    var onSearchActivated: (() -> Void)? = nil
    @Binding var isSelectMode: Bool
    @Binding var selectedIds: Set<String>
    let songs: [Song]
    let onBatchQueue: () -> Void
    let onBatchDownload: () -> Void
    let onBatchCollect: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isSelectMode {
                selectionBar
            } else if isSearching {
                HStack {
                    TextField(String(localized: "mono_session_search"), text: $searchText)
                        .font(.body)
                        .focused($isFocused)
                        .submitLabel(.search)
                        .onSubmit { isFocused = false }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    Button(String(localized: "cancel")) {
                        searchText = ""
                        isSearching = false
                        isFocused = false
                    }
                    .frame(minHeight: 44)
                }
            } else {
                HStack(spacing: 0) {
                    Text(String(localized: "artist_hot_songs"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer(minLength: 8)
                    Button {
                        isSearching = true
                        isFocused = true
                        onSearchActivated?()
                    } label: {
                        Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(String(localized: "mono_session_search"))
                    Button {
                        isSelectMode = true
                        selectedIds.removeAll()
                    } label: {
                        Image(systemName: "checklist").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(String(localized: "artist_select_songs"))
                }
            }
            Rectangle().fill(.white.opacity(0.13)).frame(height: 0.5)
                .padding(.top, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .tint(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    private var allSongsSelected: Bool {
        !songs.isEmpty && Set(songs.map(\.identityKey)).isSubset(of: selectedIds)
    }

    private var selectionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { selectionControls }
            VStack(alignment: .leading, spacing: 4) { selectionControls }
        }
    }

    @ViewBuilder
    private var selectionControls: some View {
        Button(allSongsSelected ? String(localized: "artist_deselect_all") : String(localized: "artist_select_all")) {
            selectedIds = allSongsSelected ? [] : Set(songs.map(\.identityKey))
        }
        .frame(minHeight: 44)
        Text(selectedIds.count.formatted()).font(.subheadline.monospacedDigit())
        Menu {
            Button(String(localized: "action_add_to_queue"), action: onBatchQueue)
            Button(String(localized: "song_add_to_playlist"), action: onBatchCollect)
            if AppConfig.Features.downloadEnabled {
                Button(String(localized: "song_download"), action: onBatchDownload)
            }
        } label: {
            Image(systemName: "ellipsis").frame(width: 44, height: 44)
        }
        .accessibilityLabel(String(localized: "更多"))
        .disabled(selectedIds.isEmpty)
        Button(String(localized: "cancel")) {
            isSelectMode = false
            selectedIds.removeAll()
        }
        .frame(minHeight: 44)
    }
}
