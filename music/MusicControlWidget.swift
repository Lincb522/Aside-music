import WidgetKit
import SwiftUI

// MARK: - 固定主题组件

/// 绑定单一主题的当前播放桌面组件。
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
