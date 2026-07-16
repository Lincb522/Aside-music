//
//  AriaSettingsPage.swift
//  Monologue
//
//  沉浸模式独立设置页 —— 全屏竖屏页面（替代原先窄小的面板调校 tab）。
//  从沉浸舞台点击设置进入（自动转竖屏），返回后自动回到横屏沉浸模式。
//  包含：字幕特效 / 字幕样式（字体·字号·颜色·排版·自动取色）/
//  舞台调校 / 视频背景导入与绑定。
//

import SwiftUI

struct AriaSettingsPage: View {
    let palette: AriaPalette
    /// 从沉浸舞台打开时为 true（进入转竖屏、返回恢复横屏）；
    /// 从普通播放器三点菜单打开时为 false（全程竖屏，不做任何转向）
    var managesOrientation: Bool = true

    @AppStorage("ariaLyricEffect") private var lyricEffectRaw = AriaLyricEffect.classic.rawValue
    @AppStorage("ariaLyricFont") private var lyricFontRaw = AriaLyricFontChoice.system.rawValue
    @AppStorage("ariaCustomLyricFontID") private var customFontID = ""
    @AppStorage("ariaForeignLyricFont") private var foreignLyricFontRaw = MonologuePlayerFont.followThemeRawValue
    @AppStorage("ariaForeignCustomLyricFontID") private var foreignCustomFontID = ""
    @AppStorage("ariaCanopyFragmentStage") private var canopyFragmentStage = false
    @AppStorage("ariaLyricAutoColor") private var lyricAutoColor = true
    @AppStorage("ariaLyricColorHex") private var lyricColorHex = "FFFFFF"
    @AppStorage("ariaLyricLayout") private var lyricLayoutRaw = AriaLyricLayoutChoice.center.rawValue
    @AppStorage("ariaLyricsFontScale") private var fontScale = 1.0
    @AppStorage("ariaLyricMaterialStyle") private var lyricMaterialStyleRaw = AriaLyricMaterialStyle.solid.rawValue
    @AppStorage("ariaLyricOpacity") private var lyricOpacity = 1.0
    @AppStorage("ariaLyricGlowStrength") private var lyricGlowStrength = 0.0
    @AppStorage("ariaLyricParticleDensity") private var particleDensity = 0.58
    @AppStorage("ariaLyricParticleSize") private var particleSize = 1.15
    @AppStorage("ariaLyricParticleMotion") private var particleMotion = true
    @AppStorage("ariaLyricGlassIntensity") private var glassIntensity = 0.64
    @AppStorage("lyricsForceUppercaseEnglish") private var forceUppercaseEnglish = false

    @State private var showVideoSheet = false

    private var lyricEffect: AriaLyricEffect {
        AriaLyricEffect.resolveStored(lyricEffectRaw)
    }

    private var lyricFont: AriaLyricFontChoice {
        AriaLyricFontChoice(rawValue: lyricFontRaw) ?? .system
    }

    private var lyricMaterialStyle: AriaLyricMaterialStyle {
        AriaLyricMaterialStyle.resolveStored(lyricMaterialStyleRaw)
    }

    private var lyricTypography: AriaLyricTypographyConfiguration {
        AriaLyricTypographyConfiguration(
            style: lyricMaterialStyle,
            opacity: lyricOpacity,
            glowStrength: lyricGlowStrength,
            particleDensity: particleDensity,
            particleSize: particleSize,
            particleMotion: particleMotion,
            glassIntensity: glassIntensity
        )
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: lyricColorHex) },
            set: { newColor in
                lyricColorHex = newColor.toHex()
                // 选了自定义颜色 → 自动关闭自动取色
                if lyricAutoColor { lyricAutoColor = false }
            }
        )
    }

    var body: some View {
        ZStack {
            pageBackdrop.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsScrollablePageHeader(
                        title: String(localized: "沉浸模式设置"),
                        eyebrow: "IMMERSIVE",
                        icon: .immersive
                    )

                    VStack(alignment: .leading, spacing: 26) {
                        effectSection
                        styleSection
                        tuningSection
                        videoSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 48)
                    .iPadContentWidth(720)
                }
            }
        }
        .compatFontDesign(nil)
        .environment(\.colorScheme, .dark)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                MonologueToolbarBackButton()
            }
        }
        .onAppear {
            let resolvedEffect = AriaLyricEffect.resolveStored(lyricEffectRaw)
            if lyricEffectRaw != resolvedEffect.rawValue {
                lyricEffectRaw = resolvedEffect.rawValue
            }
            // 设置页固定竖屏，返回时由沉浸舞台重新锁横屏
            if managesOrientation {
                OrientationManager.shared.exitLandscape()
            }
        }
        .onDisappear {
            if managesOrientation {
                OrientationManager.shared.enterLandscape()
            }
        }
        .fullScreenCover(isPresented: $showVideoSheet) {
            ImmersiveBackgroundSheet(palette: palette)
        }
    }

    // MARK: 背景

    private var pageBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.08), Color(red: 0.10, green: 0.10, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.accent.opacity(0.14), .clear],
                center: .init(x: 0.5, y: -0.08),
                startRadius: 0,
                endRadius: 420
            )
        }
    }

    // MARK: 字幕特效

    private var effectSection: some View {
        section(title: String(localized: "字幕特效")) {
            VStack(spacing: 8) {
                ForEach(AriaLyricEffect.allCases, id: \.rawValue) { effect in
                    optionRow(
                        label: effect.label,
                        caption: effect.caption,
                        selected: lyricEffect == effect
                    ) {
                        lyricEffectRaw = effect.rawValue
                    }
                }
            }
        }
    }

    // MARK: 字幕样式

    private var styleSection: some View {
        section(title: String(localized: "字幕样式")) {
            VStack(spacing: 14) {
                fontPreview

                // 字体（纯外语字体自动收进下方的外语字体菜单）
                VStack(alignment: .leading, spacing: 8) {
                    rowLabel(String(localized: "字体"))
                    MonologueFontPicker(
                        selectionRaw: $lyricFontRaw,
                        customFontID: $customFontID,
                        accent: palette.accent,
                        layout: .horizontal,
                        customFontScope: .cjkCapable
                    )
                }

                // 外语歌整首生效；中文歌里的英文始终用上方字体的拉丁字形
                MonologueForeignFontMenuRow(
                    selectionRaw: $foreignLyricFontRaw,
                    customFontID: $foreignCustomFontID,
                    accent: palette.accent
                )

                typographyDesignControls

                // 字号
                VStack(spacing: 6) {
                    HStack {
                        rowLabel(String(localized: "字号"))
                        Spacer()
                        Text(String(format: "%.2f×", fontScale))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Slider(value: $fontScale, in: 0.7...1.6)
                        .tint(palette.accent)
                }

                // 排版
                VStack(alignment: .leading, spacing: 8) {
                    rowLabel(String(localized: "字幕排版"))
                    if lyricEffect.usesFullStage {
                        Text(String(localized: "当前效果使用全舞台排版"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                    } else {
                        HStack(spacing: 4) {
                            ForEach(AriaLyricLayoutChoice.allCases, id: \.rawValue) { choice in
                                let selected = lyricLayoutRaw == choice.rawValue
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        lyricLayoutRaw = choice.rawValue
                                    }
                                } label: {
                                    Text(choice.label)
                                        .font(.system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(selected ? 1 : 0.45))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 34)
                                        .background(
                                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                                .fill(selected ? Color.white.opacity(0.12) : Color.clear)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }

                // 自动取色 + 自定义颜色
                VStack(spacing: 10) {
                    Toggle(isOn: $lyricAutoColor) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "自动取色"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(String(localized: "字幕颜色跟随专辑封面；选择自定义颜色后自动关闭"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .tint(palette.accent)

                    if lyricAutoColor {
                        CoverPaletteSettingsControls(accent: palette.accent)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    HStack {
                        rowLabel(String(localized: "自定义颜色"))
                        Spacer()
                        ColorPicker("", selection: customColorBinding, supportsOpacity: false)
                            .labelsHidden()
                    }
                    .opacity(lyricAutoColor ? 0.5 : 1)
                }

                if lyricEffect == .canopy {
                    Toggle(isOn: $canopyFragmentStage) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "天幕碎幕律动"))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(String(localized: "整句拆成小段接力显示，排版与动画随旋律逐句变化"))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    .tint(palette.accent)
                }

                Toggle(isOn: $forceUppercaseEnglish) {
                    rowLabel(String(localized: "英文歌词强制大写"))
                }
                .tint(palette.accent)
            }
            .padding(14)
            .background(cardBackground)
        }
    }

    private var fontPreview: some View {
        VStack(spacing: 7) {
            AriaLyricTypographyPreview(
                text: "春风又绿江南岸  Aa  123",
                fontChoice: lyricFont,
                fontSize: 29,
                configuration: lyricTypography,
                palette: palette
            )
            .id(
                "\(lyricFont.cacheIdentity)|\(customFontID)|\(lyricMaterialStyle.rawValue)|\(lyricTypography)"
            )

            Text(lyricFont.label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 82)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.accent.opacity(0.18), lineWidth: 1)
        )
    }

    private var typographyDesignControls: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                rowLabel(String(localized: "字体材质"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(AriaLyricMaterialStyle.allCases, id: \.rawValue) { style in
                            materialChip(style)
                        }
                    }
                }
            }

            typographySlider(
                title: String(localized: "透明度"),
                value: $lyricOpacity,
                range: 0.2...1,
                display: "\(Int(lyricOpacity * 100))%"
            )

            typographySlider(
                title: String(localized: "辉光"),
                value: $lyricGlowStrength,
                range: 0...1,
                display: "\(Int(lyricGlowStrength * 100))%"
            )

            if lyricMaterialStyle == .particle {
                typographySlider(
                    title: String(localized: "粒子密度"),
                    value: $particleDensity,
                    range: 0.15...1,
                    display: "\(Int(particleDensity * 100))%"
                )
                typographySlider(
                    title: String(localized: "粒子尺寸"),
                    value: $particleSize,
                    range: 0.55...2.4,
                    display: String(format: "%.2f×", particleSize)
                )
                Toggle(isOn: $particleMotion) {
                    rowLabel(String(localized: "粒子流动"))
                }
                .tint(palette.accent)
            }

            if lyricMaterialStyle == .glass {
                typographySlider(
                    title: String(localized: "玻璃质感"),
                    value: $glassIntensity,
                    range: 0.15...1,
                    display: "\(Int(glassIntensity * 100))%"
                )
            }
        }
    }

    private func materialChip(_ style: AriaLyricMaterialStyle) -> some View {
        let selected = lyricMaterialStyle == style

        return Button {
            withAnimation(.smooth(duration: 0.22)) {
                lyricMaterialStyleRaw = style.rawValue
            }
        } label: {
            Text(style.label)
                .font(.system(size: 11, weight: selected ? .bold : .medium, design: .rounded))
                .foregroundStyle(.white.opacity(selected ? 1 : 0.48))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(selected ? 0.12 : 0.045))
                )
                .overlay {
                    Capsule()
                        .stroke(
                            selected ? palette.accent.opacity(0.62) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func typographySlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        display: String
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                rowLabel(title)
                Spacer()
                Text(display)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.46))
            }
            Slider(value: value, in: range)
                .tint(palette.accent)
        }
    }

    // MARK: 舞台调校

    private var tuningSection: some View {
        section(title: String(localized: "舞台背景")) {
            AriaTuningControls(palette: palette)
                .padding(14)
                .background(cardBackground)
        }
    }

    // MARK: 视频背景

    private var videoSection: some View {
        section(title: String(localized: "视频背景")) {
            Button {
                showVideoSheet = true
            } label: {
                HStack(spacing: 12) {
                    MonologueIcon(icon: .mv, size: 17, color: palette.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(palette.accent.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "导入 / 绑定视频背景"))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(String(localized: "管理歌曲与全局沉浸背景"))
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()

                    MonologueIcon(icon: .chevronRight, size: 13, color: .white.opacity(0.35))
                }
                .padding(14)
                .background(cardBackground)
            }
            .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
        }
    }

    // MARK: 组件

    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
            content()
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.78))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.055))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }

    private func optionRow(label: String, caption: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { action() }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(caption)
                        .font(.system(size: 11.5, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                if selected {
                    MonologueIcon(icon: .checkmark, size: 16, color: palette.accent)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(selected ? 0.10 : 0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? palette.accent.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(MonologueBouncingButtonStyle(scale: 0.98))
    }
}
