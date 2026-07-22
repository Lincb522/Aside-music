// MusicControlWidget.swift
// Monologue Widget Extension

import WidgetKit
import SwiftUI

// MARK: - Widget Definition

struct NowPlayingWidget: Widget {
    let theme: WidgetTheme

    init() {
        theme = .polaroid
    }

    init(theme: WidgetTheme) {
        self.theme = theme
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: theme.widgetKind,
            provider: NowPlayingProvider(theme: theme)
        ) { entry in
            NowPlayingWidgetView(entry: entry)
        }
        .configurationDisplayName(theme.configurationDisplayName)
        .description(theme.configurationDescription)
        .supportedFamilies(theme.supportedFamilies)
        .contentMarginsDisabled()
    }
}
