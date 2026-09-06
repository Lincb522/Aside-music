import SwiftUI

extension SettingsView {
    // MARK: - 存储管理

    var cacheSection: some View {
        SettingsSection(title: String(localized: "settings_storage")) {
            SettingsRouteLinkRow(
                icon: .storage,
                title: String(localized: "settings_storage_manage"),
                subtitle: String(localized: "settings_storage_manage_desc"),
                value: cacheSize,
                destination: .storage
            )
        }
    }

    // MARK: - 设置顶部卡片

    var hasToken: Bool {
        !(SecureConfig.apiToken ?? "").isEmpty
    }

    var maskedToken: String {
        let token = SecureConfig.apiToken ?? ""
        guard token.count > 2 else { return String(repeating: "•", count: 8) }
        return String(token.prefix(2)) + String(repeating: "•", count: token.count - 2)
    }

    var headerActionButtonWidth: CGFloat {
        DeviceLayout.usesExpandedLayout ? 96 : 90
    }

    var headerFooterText: String {
        if hasToken {
            return settingsText("settings_header_footer_authorized")
        }
        return settingsText("settings_header_footer_unauthorized")
    }

    var headerFooterIcon: MonoIcon.IconType {
        hasToken ? .liked : .infoCircle
    }

    var headerFooterIconColor: Color {
        if MangaStyle.isActive {
            return hasToken ? MangaStyle.accentPink : MangaStyle.decoBlue
        }
        if NeumorphicStyle.isActive {
            return hasToken ? NeumorphicStyle.sage : NeumorphicStyle.accent
        }
        if SignalStyle.isActive {
            return hasToken ? SignalStyle.olive : SignalStyle.accent
        }
        if SequoiaStyle.isActive {
            return hasToken ? SequoiaStyle.green : SequoiaStyle.accent
        }
        if MujiStyle.isActive {
            return hasToken ? MujiStyle.tea : MujiStyle.clay
        }
        return hasToken ? Color.pink : Color.monoAccent
    }

    var headerFooterTextColor: Color {
        if MangaStyle.isActive {
            return hasToken ? MangaStyle.inkSub : MangaStyle.inkMuted
        }
        if NeumorphicStyle.isActive {
            return hasToken ? NeumorphicStyle.inkSoft : NeumorphicStyle.inkMuted
        }
        if SignalStyle.isActive {
            return hasToken ? SignalStyle.inkSoft : SignalStyle.inkMuted
        }
        if SequoiaStyle.isActive {
            return hasToken ? SequoiaStyle.inkSoft : SequoiaStyle.inkMuted
        }
        if BentoStyle.isActive {
            return hasToken ? BentoStyle.inkSoft : BentoStyle.inkMuted
        }
        if MujiStyle.isActive {
            return hasToken ? MujiStyle.inkSoft : MujiStyle.inkMuted
        }
        return hasToken ? Color.monoTextSecondary.opacity(0.72) : Color.monoTextSecondary.opacity(0.56)
    }

    var headerStatusButtonBackground: Color {
        if MangaStyle.isActive {
            return tokenSaved || hasToken ? MangaStyle.bubbleBlue : MangaStyle.bubbleWhite
        }
        if NeumorphicStyle.isActive {
            return tokenSaved || hasToken ? NeumorphicStyle.sage.opacity(0.16) : NeumorphicStyle.surfacePressed.opacity(0.76)
        }
        if SignalStyle.isActive {
            return tokenSaved || hasToken ? SignalStyle.olive.opacity(0.16) : SignalStyle.controlPressed.opacity(0.82)
        }
        if BentoStyle.isActive {
            return tokenSaved || hasToken ? BentoStyle.matcha.opacity(0.16) : BentoStyle.paperWarm.opacity(0.78)
        }
        if SequoiaStyle.isActive {
            return tokenSaved || hasToken ? SequoiaStyle.green.opacity(0.14) : SequoiaStyle.materialList.opacity(0.86)
        }
        if MujiStyle.isActive {
            return tokenSaved || hasToken ? MujiStyle.tea.opacity(0.18) : MujiStyle.surface.opacity(0.82)
        }
        if tokenSaved || hasToken {
            return Color.green.opacity(0.12)
        }
        return Color.monoSeparator.opacity(0.5)
    }

    var headerPrimaryTextColor: Color {
        if MangaStyle.isActive { return MangaStyle.ink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.ink }
        if SignalStyle.isActive { return SignalStyle.ink }
        if BentoStyle.isActive { return BentoStyle.ink }
        if SequoiaStyle.isActive { return SequoiaStyle.ink }
        if MujiStyle.isActive { return MujiStyle.ink }
        return .monoTextPrimary
    }

    var headerSecondaryTextColor: Color {
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkSoft }
        if SignalStyle.isActive { return SignalStyle.inkSoft }
        if BentoStyle.isActive { return BentoStyle.inkSoft }
        if SequoiaStyle.isActive { return SequoiaStyle.inkSoft }
        if MujiStyle.isActive { return MujiStyle.inkSoft }
        return .monoTextSecondary
    }

    var headerDeveloperIconColor: Color {
        if MangaStyle.isActive { return MangaStyle.accentPink }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if BentoStyle.isActive { return BentoStyle.tomato }
        if SequoiaStyle.isActive { return SequoiaStyle.aqua }
        if MujiStyle.isActive { return MujiStyle.tea }
        return .green
    }

    var headerPillShape: AnyShape {
        MangaStyle.isActive
            ? AnyShape(RoundedRectangle(cornerRadius: MangaStyle.buttonRadius, style: .continuous))
            : AnyShape(Capsule())
    }

    var headerSoftFill: Color {
        if MangaStyle.isActive { return MangaStyle.bubbleWhite.opacity(0.9) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.surfacePressed.opacity(0.62) }
        if SignalStyle.isActive { return SignalStyle.controlPressed.opacity(0.78) }
        if BentoStyle.isActive { return BentoStyle.paperWarm.opacity(0.82) }
        if SequoiaStyle.isActive { return SequoiaStyle.materialList.opacity(0.82) }
        if MujiStyle.isActive { return MujiStyle.surface.opacity(0.82) }
        return Color.monoSeparator.opacity(0.4)
    }

    var headerSoftStroke: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk.opacity(0.5) }
        if NeumorphicStyle.isActive { return NeumorphicStyle.separator.opacity(0.5) }
        if SignalStyle.isActive { return SignalStyle.separator.opacity(0.56) }
        if BentoStyle.isActive { return BentoStyle.hairline.opacity(0.58) }
        if SequoiaStyle.isActive { return SequoiaStyle.separator.opacity(0.72) }
        if MujiStyle.isActive { return MujiStyle.hairline.opacity(0.5) }
        return Color.clear
    }

    var headerPrimaryActionFill: Color {
        if MangaStyle.isActive { return MangaStyle.labelYellow }
        if NeumorphicStyle.isActive { return NeumorphicStyle.accent }
        if SignalStyle.isActive { return SignalStyle.accent }
        if BentoStyle.isActive { return BentoStyle.tomato }
        if SequoiaStyle.isActive { return SequoiaStyle.accent }
        if MujiStyle.isActive { return MujiStyle.clay }
        return .monoAccent
    }

    var headerPrimaryActionForeground: Color {
        if MangaStyle.isActive { return MangaStyle.strokeInk }
        if NeumorphicStyle.isActive { return Color(light: .white, dark: .black) }
        if SignalStyle.isActive { return SignalStyle.onAccent }
        if BentoStyle.isActive { return BentoStyle.onAccent }
        if SequoiaStyle.isActive { return SequoiaStyle.onAccent }
        if MujiStyle.isActive { return MujiStyle.onTint }
        return Color(light: .white, dark: .black)
    }

    var headerAvatarRadius: CGFloat {
        MangaStyle.isActive ? 16 : (MujiStyle.isActive ? 10 : (BentoStyle.isActive ? 17 : (SignalStyle.isActive ? 16 : (NeumorphicStyle.isActive ? 16 : (SequoiaStyle.isActive ? 14 : 14)))))
    }

    var playlistSyncStatusText: String {
        if let message = playlistSyncStatusMessage, !message.isEmpty {
            if let date = playlistLastSyncedAt {
                return "\(message) · \(date.formatted(date: .abbreviated, time: .shortened))"
            }
            return message
        }
        return settingsText("playlist_sync_idle")
    }

    /// aside（经典）主题使用重新设计的开发者名片，其余主题沿用原卡片。
    /// 与其他页面头部一致：滚出顶部时应用统一的收缩渐隐效果。
    var settingsHeaderCard: some View {
        Group {
            if settings.globalThemeId == .default {
                asideDeveloperCard
            } else {
                legacySettingsHeaderCard
            }
        }
        .monoPageHeaderCollapse()
    }

    // MARK: - Aside 开发者名片

    var asideDeveloperCard: some View {
        VStack(spacing: 0) {
            // 身份区：头像 + 名字/徽章 + 关于入口
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Image("WeChatAvatar")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.monoAccent.opacity(0.62),
                                            Color.monoAccent.opacity(0.1),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.4
                                )
                        )
                        .shadow(color: Color.monoAccent.opacity(0.16), radius: 10, x: 0, y: 5)

                    Circle()
                        .fill(Color.green)
                        .frame(width: 11, height: 11)
                        .overlay(
                            Circle().stroke(Color(light: .white, dark: .black).opacity(0.92), lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text("ZIJIU522")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.monoTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Text("DEV")
                            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(.monoAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(
                                Capsule()
                                    .fill(Color.monoAccent.opacity(0.13))
                                    .overlay(
                                        Capsule().stroke(Color.monoAccent.opacity(0.3), lineWidth: 0.7)
                                    )
                            )
                    }

                    HStack(spacing: 5) {
                        MonoIcon(icon: .comment, size: 11.5, color: .monoTextSecondary.opacity(0.85))
                        Text(settingsText("settings_developer_status"))
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundColor(.monoTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                SettingsNavigationLink(destination: .about) {
                    HStack(spacing: 4) {
                        Text(String(localized: "settings_about"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        MonoIcon(icon: .chevronRight, size: 9, color: .monoTextSecondary, lineWidth: 1.9)
                    }
                    .foregroundColor(.monoTextSecondary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.monoSeparator.opacity(0.36)))
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // 授权状态条：点击展开 Token 与联系开发者
            Button {
                apiTokenInput = SecureConfig.apiToken ?? apiTokenInput
                isHeaderCardExpanded.toggle()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tokenStatusColor.opacity(0.13))
                            .frame(width: 30, height: 30)
                        MonoIcon(icon: hasToken ? .lock : .unlock, size: 13, color: tokenStatusColor)
                    }

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(tokenStatusText)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.monoTextPrimary)

                        Text(asideTokenSubtitle)
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(
                                OnlineAccessManager.shared.lastTokenStatus == .expired && hasToken
                                    ? .red.opacity(0.8)
                                    : .monoTextSecondary.opacity(0.85)
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    PetWhiteDisclosureChevron(
                        isExpanded: isHeaderCardExpanded,
                        size: 10,
                        petWhiteSize: 14,
                        color: .monoTextSecondary.opacity(0.7),
                        lineWidth: 1.8
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.monoSeparator.opacity(0.28))
                )
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(MonoBouncingButtonStyle(scale: 0.98))
            .padding(.horizontal, 14)

            SettingsHeaderReveal(isExpanded: isHeaderCardExpanded) {
                asideDeveloperExpandedContent
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
            }

            // 底部寄语
            HStack(spacing: 6) {
                MonoIcon(icon: headerFooterIcon, size: 11, color: headerFooterIconColor)

                Text(headerFooterText)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundColor(headerFooterTextColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 15)
        }
        .background(asideDeveloperCardBackground)
        .animation(
            .interactiveSpring(response: 0.32, dampingFraction: 0.93, blendDuration: 0.04),
            value: isHeaderCardExpanded
        )
    }

    var asideTokenSubtitle: String {
        if hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return String(localized: "当前已过期：") + maskedToken
            }
            return maskedToken
        }
        return settingsText("settings_token_hint")
    }

    var asideDeveloperExpandedContent: some View {
        VStack(spacing: 10) {
            // 联系开发者
            HStack(spacing: 10) {
                Button {
                    PlatformPasteboard.copy("Fallin-Out0122")
                    HapticManager.shared.success()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        wechatCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { wechatCopied = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        MonoIcon(
                            icon: wechatCopied ? .checkmark : .save,
                            size: 13,
                            color: wechatCopied ? .green : .monoTextPrimary
                        )
                        Text(wechatCopied ? settingsText("settings_contact_copied") : "Fallin-Out0122")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(wechatCopied ? .green : .monoTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(wechatCopied ? Color.green.opacity(0.12) : Color.monoSeparator.opacity(0.32))
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))

                Button {
                    PlatformPasteboard.copy("Fallin-Out0122")
                    HapticManager.shared.success()
                    if let url = URL(string: "weixin://dl/contacts") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        MonoIcon(icon: .send, size: 13, color: Color(light: .white, dark: .black))
                        Text(settingsText("settings_open_wechat"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(light: .white, dark: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.monoAccent)
                    )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
            }

            // Token 输入
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    MonoIcon(icon: .unlock, size: 14, color: tokenStatusColor)
                    TextField(settingsText("access_token_input_placeholder"), text: $apiTokenInput)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .monoTextInputBehavior()
                        .submitLabel(.done)
                        .monoOnSubmit(text: $apiTokenInput) { _ in
                            submitAPIToken()
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.monoSeparator.opacity(0.32))
                )

                Button {
                    MonoTextInputCommitter.commit(text: $apiTokenInput) { _ in
                        submitAPIToken()
                    }
                } label: {
                    Text(settingsText("common_save"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(light: .white, dark: .black))
                        .frame(width: 48, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.monoAccent)
                        )
                }
                .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
            }

            if ServerLineManager.isBackupConfigured {
                ServerLineSelectorView()
            }
        }
    }

    var asideDeveloperCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.monoGlassTint.opacity(0.55))
            .monoGlass(cornerRadius: 24)
            .overlay(alignment: .topTrailing) {
                // 右上角强调色光晕，随封面主题色
                Circle()
                    .fill(Color.monoAccent.opacity(0.14))
                    .frame(width: 170, height: 170)
                    .blur(radius: 52)
                    .offset(x: 55, y: -70)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    // MARK: - 其他主题的开发者卡片（原设计）

    var legacySettingsHeaderCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("WeChatAvatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: headerAvatarRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: headerAvatarRadius, style: .continuous)
                            .stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1 : 0.7)
                    }
                    .shadow(color: .black.opacity(MangaStyle.isActive ? 0.02 : 0.08), radius: 3, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ZIJIU522")
                        .font(MangaStyle.isActive ? MangaStyle.titleFont(18, weight: .black) : (MujiStyle.isActive ? MujiStyle.titleFont(18, weight: .medium) : .system(size: 17, weight: .bold, design: .rounded)))
                        .foregroundColor(headerPrimaryTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    HStack(spacing: 5) {
                        MonoIcon(icon: .comment, size: 12, color: headerDeveloperIconColor)
                        Text(settingsText("settings_developer_status"))
                            .font(themedSettingsFont(11, weight: .medium))
                            .foregroundColor(headerSecondaryTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    SettingsNavigationLink(destination: .about) {
                        Text(String(localized: "settings_about"))
                            .font(themedSettingsFont(11, weight: .semibold))
                            .foregroundColor(headerSecondaryTextColor)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background {
                                headerPillShape
                                    .fill(headerSoftFill)
                                    .overlay(headerPillShape.stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6))
                            }
                    }
                    .frame(width: headerActionButtonWidth)
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))

                    Button {
                        apiTokenInput = SecureConfig.apiToken ?? apiTokenInput
                        isHeaderCardExpanded.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            MonoIcon(
                                icon: hasToken ? .lock : .unlock,
                                size: 10,
                                color: tokenStatusColor
                            )

                            Text(tokenStatusText)
                                .font(themedSettingsFont(11, weight: .semibold))
                                .minimumScaleFactor(0.84)

                            PetWhiteDisclosureChevron(
                                isExpanded: isHeaderCardExpanded,
                                size: 10,
                                petWhiteSize: 14,
                                color: tokenStatusColor,
                                lineWidth: 1.8
                            )
                        }
                        .foregroundColor(tokenStatusColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            headerPillShape
                                .fill(headerStatusButtonBackground)
                                .overlay(headerPillShape.stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6))
                        )
                    }
                    .frame(width: headerActionButtonWidth)
                    .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
                }
                .layoutPriority(2)
            }

            SettingsHeaderReveal(isExpanded: isHeaderCardExpanded) {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Button {
                            PlatformPasteboard.copy("Fallin-Out0122")
                            HapticManager.shared.success()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                wechatCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { wechatCopied = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                MonoIcon(icon: wechatCopied ? .checkmark : .save, size: 13, color: wechatCopied ? headerDeveloperIconColor : headerPrimaryTextColor)
                                Text(wechatCopied ? settingsText("settings_contact_copied") : "Fallin-Out0122")
                                    .font(themedSettingsFont(13, weight: .semibold))
                            }
                            .foregroundColor(wechatCopied ? headerDeveloperIconColor : headerPrimaryTextColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(wechatCopied ? headerDeveloperIconColor.opacity(0.13) : headerSoftFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6)
                                    )
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))

                        Button {
                            PlatformPasteboard.copy("Fallin-Out0122")
                            HapticManager.shared.success()
                            if let url = URL(string: "weixin://dl/contacts") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                MonoIcon(icon: .send, size: 13, color: headerPrimaryActionForeground)
                                Text(settingsText("settings_open_wechat"))
                                    .font(themedSettingsFont(13, weight: .semibold))
                            }
                            .foregroundColor(headerPrimaryActionForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(headerPrimaryActionFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(MangaStyle.isActive ? MangaStyle.strokeInk : Color.clear, lineWidth: 1.3)
                                    )
                            )
                        }
                        .buttonStyle(MonoBouncingButtonStyle(scale: 0.96))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            MonoIcon(icon: hasToken ? .lock : .unlock, size: 14, color: tokenStatusColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(settingsText("access_token_title"))
                                    .font(themedSettingsFont(12, weight: .semibold))
                                    .foregroundColor(headerPrimaryTextColor)

                                if hasToken {
                                    if OnlineAccessManager.shared.lastTokenStatus == .expired {
                                        Text("当前已过期：" + maskedToken)
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(.red.opacity(0.8))
                                    } else {
                                        Text(settingsFormat("settings_token_authorized_format", maskedToken))
                                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                                            .foregroundColor(headerSecondaryTextColor)
                                    }
                                } else {
                                    Text(settingsText("settings_token_hint"))
                                        .font(themedSettingsFont(13, weight: .medium))
                                        .foregroundColor(headerSecondaryTextColor.opacity(0.78))
                                }
                            }

                            Spacer()
                        }

                        HStack(spacing: 10) {
                            HStack(spacing: 8) {
                                MonoIcon(icon: .unlock, size: 14, color: tokenStatusColor)
                                TextField(settingsText("access_token_input_placeholder"), text: $apiTokenInput)
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .monoTextInputBehavior()
                                    .submitLabel(.done)
                                    .monoOnSubmit(text: $apiTokenInput) { _ in
                                        submitAPIToken()
                                    }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(headerSoftFill.opacity(MangaStyle.isActive ? 0.74 : 1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(headerSoftStroke, lineWidth: MangaStyle.isActive ? 1.2 : 0.6)
                                    )
                            )

                            Button {
                                MonoTextInputCommitter.commit(text: $apiTokenInput) { _ in
                                    submitAPIToken()
                                }
                            } label: {
                                Text(settingsText("common_save"))
                                    .font(themedSettingsFont(13, weight: .semibold))
                                    .foregroundColor(headerPrimaryActionForeground)
                                    .frame(width: 44, height: 36)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(headerPrimaryActionFill)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(MangaStyle.isActive ? MangaStyle.strokeInk : Color.clear, lineWidth: 1.3)
                                            )
                                    )
                            }
                            .buttonStyle(MonoBouncingButtonStyle(scale: 0.92))
                        }
                    }

                    if ServerLineManager.isBackupConfigured {
                        ServerLineSelectorView()
                    }
                }
                .padding(.top, 16)
            }

            HStack(spacing: 6) {
                MonoIcon(icon: headerFooterIcon, size: 11, color: headerFooterIconColor)

                Text(headerFooterText)
                    .font(themedSettingsFont(12, weight: .medium))
                    .foregroundColor(headerFooterTextColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, isHeaderCardExpanded ? 14 : 12)
            .transition(.opacity)
        }
        .padding(16)
        .themedSettingsStandaloneCard(cornerRadius: 22, tint: MangaStyle.paperWarm)
    }

    var otherSection: some View {
        SettingsSection(title: String(localized: "developer_tools_title")) {
            if ClarityStyle.isActive {
                // Settings is already a destination in Clarity's NavigationStack.
                // Push directly so this page is not queued underneath Settings.
                SettingsLinkRow(
                    icon: .unlock,
                    title: String(localized: "dev_mode_title"),
                    value: String(
                        localized: AppConfig.Features.fullDeveloperToolsEnabled
                            ? "dev_mode_access_full"
                            : "dev_mode_access_basic"
                    ),
                    destination: DeveloperToolsView()
                )
            } else {
                SettingsRouteLinkRow(
                    icon: .unlock,
                    title: String(localized: "dev_mode_title"),
                    value: String(
                        localized: AppConfig.Features.fullDeveloperToolsEnabled
                            ? "dev_mode_access_full"
                            : "dev_mode_access_basic"
                    ),
                    destination: .developerTools
                )
            }
        }
    }


    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var tokenStatusText: String {
        if tokenSaved {
            return settingsText("settings_token_saved")
        }
        if hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return String(localized: "已过期")
            }
            return settingsText("settings_token_authorized")
        }
        return settingsText("settings_token_unauthorized")
    }

    var tokenStatusColor: Color {
        if tokenSaved || hasToken {
            if OnlineAccessManager.shared.lastTokenStatus == .expired {
                return .red
            }
            if MangaStyle.isActive { return MangaStyle.decoBlue }
            if NeumorphicStyle.isActive { return NeumorphicStyle.sage }
            if CapsuleStyle.isActive { return CapsuleStyle.mint }
            if SequoiaStyle.isActive { return SequoiaStyle.green }
            if MujiStyle.isActive { return MujiStyle.tea }
            return .green
        }
        if MangaStyle.isActive { return MangaStyle.inkSub }
        if NeumorphicStyle.isActive { return NeumorphicStyle.inkMuted }
        if CapsuleStyle.isActive { return CapsuleStyle.inkMuted }
        if SequoiaStyle.isActive { return SequoiaStyle.inkMuted }
        if MujiStyle.isActive { return MujiStyle.inkMuted }
        return .monoTextSecondary
    }

}
