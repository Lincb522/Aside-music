import Combine
import SwiftUI

extension PodcastView {
    // MARK: - 广播电台

    var broadcastSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            podcastSectionHeader(
                title: String(localized: "podcast_broadcast"),
                destination: .broadcastList
            )

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(viewModel.broadcastChannels) { channel in
                        Button {
                            HapticStyle.light.trigger()
                            selectedBroadcastChannel = channel
                        } label: {
                            broadcastCard(channel: channel)
                        }
                        .buttonStyle(MonoBouncingButtonStyle())
                        .compatScrollTransition(animation: .spring(response: 0.35)) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1 : 0.93)
                                .opacity(phase.isIdentity ? 1 : 0.5)
                                .offset(y: phase.isIdentity ? 0 : phase.value * 8)
                        }
                    }
                }
                .compatScrollTargetLayout()
                .padding(.horizontal, padH)
            }
            .compatViewAlignedScrollBehavior(limitNever: true)
            .scrollIndicators(.hidden)
            .themeRenderScrollLayer()
        }
    }

    @ViewBuilder
    func broadcastCard(channel: BroadcastChannel) -> some View {
        if isAside {
            asideBroadcastCard(channel: channel)
        } else {
            themedBroadcastCard(channel: channel)
        }
    }

    /// aside 广播卡：发丝封面 + 直播点标
    func asideBroadcastCard(channel: BroadcastChannel) -> some View {
        let bcSize = broadcastCardSize

        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if let url = channel.coverImageUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.monoSeparator.opacity(0.35))
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: bcSize, height: bcSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.monoSeparator.opacity(0.35))
                        .frame(width: bcSize, height: bcSize)
                        .overlay(
                            MonoIcon(icon: .radio, size: 26, color: .monoTextSecondary.opacity(0.5), lineWidth: 1.4)
                        )
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.monoAccentRed)
                        .frame(width: 5, height: 5)

                    Text("FM")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Capsule().fill(Color.black.opacity(0.38)))
                .padding(7)
            }
            .frame(width: bcSize, height: bcSize)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.monoTextPrimary.opacity(0.08), lineWidth: 0.8)
            )

            Text(channel.displayName)
                .font(.rounded(size: 13, weight: .semibold))
                .foregroundColor(.monoTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: bcSize, height: 34, alignment: .topLeading)
                .padding(.top, 8)

            Text(channel.displayProgram ?? " ")
                .font(.rounded(size: 11, weight: .medium))
                .foregroundColor(.monoTextSecondary.opacity(0.85))
                .lineLimit(1)
                .frame(width: bcSize, alignment: .leading)
                .padding(.top, 3)
        }
        .frame(width: bcSize)
    }

    func themedBroadcastCard(channel: BroadcastChannel) -> some View {
        let bcSize = broadcastCardSize
        let bcCR: CGFloat = MinimalWhiteStyle.isActive ? 12 : (MujiStyle.isActive ? 8 : ((NeumorphicStyle.isActive || SequoiaStyle.isActive) ? 18 : (DeviceLayout.isPad ? 18 : 16)))
        let placeholderFill: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.controlGlassFill : (SequoiaStyle.isActive ? SequoiaStyle.materialList : (NeumorphicStyle.isActive ? NeumorphicStyle.surfacePressed : Color.monoGlassTint))
        let iconColor: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.aqua : (NeumorphicStyle.isActive ? NeumorphicStyle.sage : .monoTextSecondary))
        let titleFont: Font = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .medium) : (SequoiaStyle.isActive ? SequoiaStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold) : (MujiStyle.isActive ? MujiStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.bodyFont(DeviceLayout.isPad ? 14 : 13, weight: .semibold) : .system(size: DeviceLayout.isPad ? 14 : 13, weight: .medium, design: .rounded))))
        let subtitleFont: Font = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular) : (SequoiaStyle.isActive ? SequoiaStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular) : (MujiStyle.isActive ? MujiStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .regular) : (NeumorphicStyle.isActive ? NeumorphicStyle.labelFont(DeviceLayout.isPad ? 12 : 11, weight: .medium) : .system(size: DeviceLayout.isPad ? 12 : 11, design: .rounded))))
        let titleColor: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.ink : (SequoiaStyle.isActive ? SequoiaStyle.ink : (NeumorphicStyle.isActive ? NeumorphicStyle.ink : .monoTextPrimary))
        let subtitleColor: Color = MinimalWhiteStyle.isActive ? MinimalWhiteStyle.inkMuted : (SequoiaStyle.isActive ? SequoiaStyle.inkSoft : (NeumorphicStyle.isActive ? NeumorphicStyle.inkSoft : .monoTextSecondary))

        return VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let url = channel.coverImageUrl {
                    CachedAsyncImage(url: url) {
                        RoundedRectangle(cornerRadius: bcCR)
                            .fill(placeholderFill)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: bcSize, height: bcSize)
                    .clipShape(RoundedRectangle(cornerRadius: bcCR, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: bcCR, style: .continuous)
                        .fill(placeholderFill)
                        .frame(width: bcSize, height: bcSize)
                        .overlay(
                            MonoIcon(icon: .radio, size: 30, color: iconColor, lineWidth: 1.4)
                        )
                }

                VStack {
                    HStack {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.monoAccentRed)
                                .frame(width: 6, height: 6)
                            Text("FM")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.15)))
                        .monoGlassCapsule()

                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(width: bcSize, height: bcSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(channel.displayName)
                    .font(titleFont)
                    .foregroundColor(titleColor)
                    .lineLimit(2)
                    .frame(height: DeviceLayout.isPad ? 36 : 34, alignment: .topLeading)

                Text(channel.displayProgram ?? " ")
                    .font(subtitleFont)
                    .foregroundColor(subtitleColor)
                    .lineLimit(1)
            }
        }
        .frame(width: bcSize)
        .padding(MinimalWhiteStyle.isActive ? 8 : 0)
        .background {
            if MinimalWhiteStyle.isActive {
                MinimalWhiteSurfaceBackground(cornerRadius: 14, elevated: false, tint: MinimalWhiteStyle.glassFill)
            } else if NeumorphicStyle.isActive {
                NeumorphicSurfaceBackground(cornerRadius: 18, elevated: true)
            } else if SequoiaStyle.isActive {
                SequoiaSurfaceBackground(cornerRadius: 18, elevated: false, role: .list)
            }
        }
    }

    // MARK: - 工具方法

    func formatCount(_ count: Int) -> String {
        if count >= 100_000_000 {
            return String(format: String(localized: "count_hundred_million"), Double(count) / 100_000_000)
        } else if count >= 10000 {
            return String(format: String(localized: "count_ten_thousand"), Double(count) / 10000)
        }
        return "\(count)"
    }
}
