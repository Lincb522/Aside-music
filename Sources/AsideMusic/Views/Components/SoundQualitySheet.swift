import SwiftUI

struct SoundQualitySheet: View {
    let currentQuality: SoundQuality
    let onSelect: (SoundQuality) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let qualities: [SoundQuality] = SoundQuality.allCases.filter { $0 != .none && $0 != .higher }
    
    var body: some View {
        ZStack {
            AsideBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                HStack {
                    Text("音质选择")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        AsideIcon(icon: .close, size: 14, color: .asideTextSecondary)
                            .padding(10)
                            .background(Color.asideSeparator)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(qualities.enumerated()), id: \.element) { index, quality in
                            Button(action: { onSelect(quality) }) {
                                qualityRow(quality)
                            }
                            .buttonStyle(.plain)
                            
                            if index < qualities.count - 1 {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.asideCardBackground)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)
                }
            }
        }
    }
    
    private func qualityRow(_ quality: SoundQuality) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(currentQuality == quality ? Color.asideIconBackground : Color.asideIconBackground.opacity(0.08))
                    .frame(width: 32, height: 32)
                
                AsideIcon(icon: .soundQuality, size: 16, color: currentQuality == quality ? .asideIconForeground : .asideTextPrimary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(quality.displayName)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.asideTextPrimary)
                    
                    if let badge = quality.badgeText {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.asideIconForeground)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.asideIconBackground)
                            .cornerRadius(4)
                    }
                }
                
                Text(quality.subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.asideTextSecondary)
            }
            
            Spacer()
            
            if currentQuality == quality {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.asideTextPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
