import Combine
import QQMusicKit
import SwiftUI
import UniformTypeIdentifiers

extension ScrollableLibraryExperience {
    @ViewBuilder
    var header: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteHeader
        } else if LiquidGlassStyle.isActive {
            liquidGlassHeaderDeck
        } else if PetWhiteStyle.isActive {
            petWhiteHeaderDeck
        } else if NeumorphicStyle.isActive {
            neumorphicHeaderDeck
        } else if SignalStyle.isActive {
            signalHeaderDeck
        } else if SequoiaStyle.isActive {
            sequoiaHeaderDeck
        } else if CapsuleStyle.isActive {
            capsuleHeaderDeck
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if MujiStyle.isActive {
                    // 清新刊头：圆点眉题 + 衬线大标题
                    VStack(alignment: .leading, spacing: 11) {
                        HStack(alignment: .center, spacing: 8) {
                            MujiDotMark()

                            Text("MUSIC SHELF")
                                .font(MujiStyle.labelFont(10, weight: .semibold))
                                .foregroundStyle(MujiStyle.clay)
                                .tracking(2.2)
                                .fixedSize()
                        }

                        Text(String(localized: "tabbar_library"))
                            .font(MujiStyle.titleFont(30, weight: .medium))
                            .foregroundStyle(MujiStyle.ink)
                            .tracking(0.3)
                    }
                } else {
                    Text(LocalizedStringKey("tabbar_library"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.monoTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                tabStrip
            }
            .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
            .padding(.top, DeviceLayout.headerTopPadding + 8)
        }
    }

    var minimalWhiteHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(String(localized: "tabbar_library"))
                .font(MinimalWhiteStyle.titleFont(30, weight: .semibold))
                .foregroundStyle(MinimalWhiteStyle.ink)

            minimalWhiteTabStrip
        }
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    var minimalWhiteTabStrip: some View {
        HStack(spacing: 4) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                let selected = tabIndex == index
                Button {
                    selectTab(tab, index: index)
                } label: {
                    Text(tab.localizedKey)
                        .font(MinimalWhiteStyle.labelFont(13, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? MinimalWhiteStyle.ink : MinimalWhiteStyle.inkMuted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                MinimalWhiteCapsuleBackground(elevated: false, selected: true)
                            }
                        }
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(MinimalWhiteCapsuleBackground(elevated: true))
    }

    var neumorphicHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "tabbar_library"))
                .font(NeumorphicStyle.titleFont(29, weight: .semibold))
                .foregroundStyle(NeumorphicStyle.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
    }

    var petWhiteHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(String(localized: "tabbar_library"))
                    .font(PetWhiteStyle.titleFont(26, weight: .bold))
                    .foregroundStyle(PetWhiteStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                PetWhitePetPetIcon(size: 36)
            }
            .padding(.horizontal, 2)

            tabStrip
        }
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 2)
    }

    var signalHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        SignalPulseDot(tint: activeTabTint, size: 18)

                        Text(activeTabEyebrow)
                            .font(SignalStyle.monoFont(10, weight: .semibold))
                            .foregroundStyle(activeTabTint)
                    }

                    Text(String(localized: "tabbar_library"))
                        .font(SignalStyle.titleFont(27, weight: .bold))
                        .foregroundStyle(SignalStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    SignalLibraryMiniBars(tint: activeTabTint)
                    SignalPill(text: activeTabShortLabel, tint: activeTabTint, selected: true, compact: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(SignalSurfaceBackground(cornerRadius: 18, elevated: false, pressed: true, fill: SignalStyle.control))
            }

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 10)
    }

    var sequoiaHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 13) {
                VStack(spacing: 4) {
                    Capsule()
                        .fill(activeTabTint)
                        .frame(width: 4, height: 26)
                    Capsule()
                        .fill(SequoiaStyle.separator)
                        .frame(width: 4, height: 10)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activeTabEyebrow)
                        .font(SequoiaStyle.labelFont(10, weight: .semibold))
                        .foregroundStyle(activeTabTint)
                        .tracking(0.9)

                    Text(String(localized: "tabbar_library"))
                        .font(SequoiaStyle.titleFont(25, weight: .semibold))
                        .foregroundStyle(SequoiaStyle.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 9) {
                    SequoiaMeter(tint: activeTabTint, count: 9)
                    SequoiaPill(text: activeTabShortLabel, tint: activeTabTint, selected: true, compact: true)
                }
            }
            .padding(14)
            .background(SequoiaChromeBar(cornerRadius: 23))

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    @ViewBuilder
    var tabStrip: some View {
        if MinimalWhiteStyle.isActive {
            minimalWhiteTabStrip
        } else if LiquidGlassStyle.isActive {
            liquidGlassTabDeck
        } else if PetWhiteStyle.isActive {
            petWhiteTabDeck
        } else if NeumorphicStyle.isActive {
            neumorphicTabDeck
        } else if SignalStyle.isActive {
            signalTabDeck
        } else if SequoiaStyle.isActive {
            sequoiaTabDeck
        } else if CapsuleStyle.isActive {
            capsuleTabDeck
        } else if MujiStyle.isActive {
            mujiTabStrip
        } else {
            HStack(spacing: 6) {
                ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                    let selected = tabIndex == index
                    Button {
                        selectTab(tab, index: index)
                    } label: {
                        HStack(spacing: 6) {
                            MonoIcon(icon: icon(for: tab), size: 13, color: tabForeground(selected: selected), lineWidth: 1.8)
                            Text(tab.localizedKey)
                                .font(tabFont(selected: selected))
                                .foregroundColor(tabForeground(selected: selected))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: NeumorphicStyle.isActive ? 40 : 38)
                        .background(tabBackground(selected: selected, tint: tint(for: tab)))
                        .contentShape(RoundedRectangle(cornerRadius: tabCornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(NeumorphicStyle.isActive ? 5 : 4)
            .background(panelBackground(cornerRadius: NeumorphicStyle.isActive ? 20 : 14))
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: tabIndex)
        }
    }

    /// Muji：目次式页签 —— 裸排衬线文字 + 陶土短下划线，无容器
    var mujiTabStrip: some View {
        HStack(spacing: 24) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                let selected = tabIndex == index
                Button {
                    selectTab(tab, index: index)
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.localizedKey)
                            .font(MujiStyle.bodyFont(14.5, weight: selected ? .medium : .regular))
                            .foregroundStyle(selected ? MujiStyle.ink : MujiStyle.inkMuted)
                            .lineLimit(1)
                            .animation(.none, value: tabIndex)

                        Rectangle()
                            .fill(MujiStyle.clay.opacity(0.85))
                            .frame(width: 16, height: 1.4)
                            .opacity(selected ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: tabIndex)
    }

    var capsuleHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "tabbar_library"))
                .font(CapsuleStyle.titleFont(25, weight: .bold))
                .foregroundStyle(CapsuleStyle.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    var capsuleTabDeck: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                capsuleTabButton(tab: tab, index: index)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: tabIndex)
    }

    func capsuleTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            VStack(spacing: 5) {
                MonoIcon(
                    icon: icon(for: tab),
                    size: 14,
                    color: selected ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(CapsuleStyle.labelFont(10.5, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? CapsuleStyle.readableLabel(on: tint) : CapsuleStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(selected ? tint : Color.clear)
            }
        }
        .buttonStyle(CapsulePressStyle())
    }

    var liquidGlassHeaderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                LiquidGlassRefractionHeaderShape()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LiquidGlassRefractionHeaderShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        activeTabTint.opacity(0.2),
                                        LiquidGlassStyle.glassRaised.opacity(0.74),
                                        LiquidGlassStyle.cyan.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        LiquidGlassRefractionHeaderShape()
                            .strokeBorder(Color.white.opacity(0.48), lineWidth: 0.75)
                    )

                LiquidGlassCausticField(opacity: 0.1)
                    .clipShape(LiquidGlassRefractionHeaderShape())

                HStack(alignment: .bottom, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            LiquidGlassDropletMark(tint: activeTabTint)

                            Text(activeTabShortLabel)
                                .font(LiquidGlassStyle.labelFont(11, weight: .bold))
                                .foregroundStyle(activeTabTint)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(activeTabTint.opacity(0.13)))
                        }

                        Text(String(localized: "tabbar_library"))
                            .font(LiquidGlassStyle.titleFont(31, weight: .semibold))
                            .foregroundStyle(LiquidGlassStyle.ink)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    LiquidGlassIconBadge(icon: icon(for: selectedTab), tint: activeTabTint, size: 54)
                }
                .padding(16)
            }
            .frame(height: 126)

            tabStrip
        }
        .padding(.horizontal, DeviceLayout.libraryHorizontalPadding)
        .padding(.top, DeviceLayout.headerTopPadding + 8)
    }

    var liquidGlassTabDeck: some View {
        HStack(spacing: 7) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                liquidGlassTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(LiquidGlassSurfaceBackground(cornerRadius: 24, elevated: true, role: .chrome))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    var petWhiteTabDeck: some View {
        HStack(spacing: 5) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                petWhiteTabButton(tab: tab, index: index)
            }
        }
        .padding(4)
        .background(PetWhiteSurfaceBackground(cornerRadius: PetWhiteStyle.cardRadius, elevated: true, tint: PetWhiteStyle.surfacePressed, accent: activeTabTint))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    func petWhiteTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            VStack(spacing: 3) {
                PetWhitePackIcon(
                    icon: icon(for: tab),
                    size: 16,
                    visualScale: selected ? 1.08 : 0.98,
                    fallbackColor: selected ? PetWhiteStyle.ink : PetWhiteStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(PetWhiteStyle.labelFont(10.5, weight: selected ? .black : .bold))
                    .foregroundStyle(selected ? PetWhiteStyle.ink : PetWhiteStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(PetWhiteDockSelectionBackground(tint: tint, isSelected: selected, cornerRadius: 14))
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
    }

    func liquidGlassTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonoIcon(
                    icon: icon(for: tab),
                    size: 13,
                    color: selected ? tint : LiquidGlassStyle.inkSoft,
                    lineWidth: selected ? 1.8 : 1.45
                )

                Text(tab.localizedKey)
                    .font(LiquidGlassStyle.labelFont(11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? LiquidGlassStyle.ink : LiquidGlassStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
                LiquidGlassSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    fill: selected ? tint.opacity(0.16) : nil,
                    role: selected ? .selected : .list
                )
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
    }

    var neumorphicTabDeck: some View {
        HStack(spacing: 8) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                neumorphicTabButton(tab: tab, index: index)
            }
        }
        .padding(6)
        .background(NeumorphicSurfaceBackground(cornerRadius: 24, elevated: true, lightweight: true))
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: tabIndex)
    }

    func neumorphicTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            VStack(spacing: 5) {
                MonoIcon(
                    icon: icon(for: tab),
                    size: 15,
                    color: selected ? tint : NeumorphicStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(NeumorphicStyle.labelFont(10, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? NeumorphicStyle.ink : NeumorphicStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                NeumorphicSurfaceBackground(
                    cornerRadius: 17,
                    elevated: selected,
                    pressed: !selected,
                    tint: selected ? tint.opacity(0.17) : NeumorphicStyle.surface,
                    lightweight: true
                )
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
    }

    var signalTabDeck: some View {
        HStack(spacing: 7) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                signalTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(SignalSurfaceBackground(cornerRadius: 22, elevated: true, fill: SignalStyle.device))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    func signalTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonoIcon(
                    icon: icon(for: tab),
                    size: 14,
                    color: selected ? tint : SignalStyle.inkSoft,
                    lineWidth: selected ? 1.9 : 1.55
                )

                Text(tab.localizedKey)
                    .font(SignalStyle.labelFont(11.5, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? SignalStyle.ink : SignalStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                SignalSurfaceBackground(
                    cornerRadius: 16,
                    elevated: selected,
                    pressed: !selected,
                    fill: selected ? tint.opacity(0.16) : SignalStyle.control
                )
            )
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
    }

    var sequoiaTabDeck: some View {
        HStack(spacing: 6) {
            ForEach(Array(tabs.enumerated()), id: \.element) { index, tab in
                sequoiaTabButton(tab: tab, index: index)
            }
        }
        .padding(5)
        .background(SequoiaSurfaceBackground(cornerRadius: 18, elevated: true, role: .chrome))
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: tabIndex)
    }

    func sequoiaTabButton(tab: LibraryViewModel.LibraryTab, index: Int) -> some View {
        let selected = tabIndex == index
        let tint = tint(for: tab)

        return Button {
            selectTab(tab, index: index)
        } label: {
            HStack(spacing: 6) {
                MonoIcon(
                    icon: icon(for: tab),
                    size: 13,
                    color: selected ? tint : SequoiaStyle.inkSoft,
                    lineWidth: selected ? 1.75 : 1.45
                )

                Text(tab.localizedKey)
                    .font(SequoiaStyle.labelFont(11.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? SequoiaStyle.ink : SequoiaStyle.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SequoiaStyle.selectedWash)
                        .matchedGeometryEffect(id: "library-tab", in: sequoiaLibraryNamespace)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(tint.opacity(0.24), lineWidth: 0.55)
                        )
                }
            }
        }
        .buttonStyle(MonoBouncingButtonStyle(scale: 0.95))
    }

}
