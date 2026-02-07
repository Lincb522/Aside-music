import SwiftUI
import LiquidGlassEffect

struct UserPlaylistRow: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 16) {
            CachedAsyncImage(url: playlist.coverUrl) {
                Color.gray.opacity(0.1)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 60, height: 60)
            .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.rounded(size: 16, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
                Text(String(format: NSLocalizedString("songs_count_by", comment: "Songs count and creator"), playlist.trackCount ?? 0, playlist.creator?.nickname ?? "Unknown"))
                    .font(.rounded(size: 14, weight: .medium))
                    .foregroundColor(.asideTextSecondary)
            }
            Spacer()
            AsideIcon(icon: .back, size: 16, color: .asideTextSecondary)
                .rotationEffect(.degrees(180))
        }
        .padding()
        .background {
            ZStack {
                // 列表项使用较低帧率
                LiquidGlassMetalView(cornerRadius: 16, backgroundCaptureFrameRate: 20)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.asideCardBackground.opacity(0.4))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}
