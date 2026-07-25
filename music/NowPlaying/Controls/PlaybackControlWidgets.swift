import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 控制中心组件

/// iOS 18 控制中心中的播放/暂停按钮。
@available(iOS 18, *)
struct PlayPauseControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "zijiu.Monologue.com.control.playpause") {
            ControlWidgetButton(action: TogglePlaybackIntent()) {
                Label("播放/暂停", systemImage: "play.pause.fill")
            }
        }
        .displayName("Mono 播放/暂停")
    }
}

/// iOS 18 控制中心中的下一首按钮。
@available(iOS 18, *)
struct NextTrackControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "zijiu.Monologue.com.control.next") {
            ControlWidgetButton(action: NextTrackIntent()) {
                Label("下一首", systemImage: "forward.fill")
            }
        }
        .displayName("Mono 下一首")
    }
}
