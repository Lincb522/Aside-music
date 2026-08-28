import Combine
import QQMusicKit
import SwiftUI

extension ProfileView {
    var profileHeroCard: some View {
        let profile = cachedProfile ?? viewModel.userProfile

        return HStack(spacing: 16) {
            if let avatarUrl = profile?.avatarUrl, let url = URL(string: avatarUrl) {
                CachedAsyncImage(url: url, width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize) {
                    Circle().fill(Color.monoSeparator)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                .clipShape(Circle())
                .overlay(Circle().stroke(PetWhiteStyle.isActive ? PetWhiteStyle.stroke : Color.clear, lineWidth: 2))
            } else if PetWhiteStyle.isActive {
                PetWhiteMascotMark(kind: .pair, size: DeviceLayout.profileAvatarSize)
                    .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                    .background(
                        PetWhiteSurfaceBackground(
                            cornerRadius: DeviceLayout.profileAvatarSize * 0.5,
                            elevated: true,
                            tint: PetWhiteStyle.surfaceRaised,
                            accent: PetWhiteStyle.mint
                        )
                    )
                    .clipShape(Circle())
                    .overlay(Circle().stroke(PetWhiteStyle.stroke, lineWidth: 1))
            } else {
                Circle()
                    .fill(Color.monoSeparator)
                    .frame(width: DeviceLayout.profileAvatarSize, height: DeviceLayout.profileAvatarSize)
                    .overlay(
                        MonoIcon(icon: .profile, size: 30, color: .monoTextSecondary.opacity(0.4))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile?.nickname ?? NSLocalizedString("default_nickname", comment: ""))
                        .font(MangaStyle.isActive ? MangaStyle.titleFont(22, weight: .black) : (PetWhiteStyle.isActive ? PetWhiteStyle.titleFont(22, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(22, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.titleFont(22, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.titleFont(21, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.titleFont(21, weight: .semibold) : .system(size: 20, weight: .bold, design: .rounded)))))))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : .monoTextPrimary)
                        .lineLimit(1)

                    if let level = userLevel {
                        Text("Lv.\(level)")
                            .font(MangaStyle.isActive ? MangaStyle.comicFont(10, weight: .bold) : (PetWhiteStyle.isActive ? PetWhiteStyle.labelFont(10, weight: .black) : (MujiStyle.isActive ? MujiStyle.labelFont(10, weight: .semibold) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(10, weight: .semibold) : (SignalStyle.isActive ? SignalStyle.labelFont(10, weight: .bold) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(10, weight: .semibold) : .system(size: 10, weight: .bold, design: .rounded)))))))
                            .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.ink : .monoIconForeground)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(PetWhiteStyle.isActive ? PetWhiteStyle.mint : Color.monoIconBackground)
                            .clipShape(Capsule())
                    }
                }

                if let signature = profile?.signature, !signature.isEmpty {
                    Text(signature)
                        .font(MangaStyle.isActive ? MangaStyle.comicFont(12, weight: .medium) : (PetWhiteStyle.isActive ? PetWhiteStyle.bodyFont(12, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.labelFont(12, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(12, weight: .regular) : (SignalStyle.isActive ? SignalStyle.labelFont(12, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(12, weight: .regular) : .system(size: 12, weight: .regular, design: .rounded)))))))
                        .foregroundColor(PetWhiteStyle.isActive ? PetWhiteStyle.inkSoft : .monoTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(ThemedPageStyle.isActive ? 16 : 18)
        .themedProfileSurface(cornerRadius: PetWhiteStyle.isActive ? PetWhiteStyle.cardRadius : (MangaStyle.isActive ? MangaStyle.cardRadius : (MujiStyle.isActive ? 12 : (NeumorphicStyle.isActive ? 24 : (SignalStyle.isActive ? 16 : (SequoiaStyle.isActive ? 18 : 22))))), mangaTint: MangaStyle.paperWarm)
    }

}
