// musicBundle.swift
// Widget Extension 入口

import WidgetKit
import SwiftUI

@main
struct musicBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
        if #available(iOS 18, *) {
            PlayPauseControlWidget()
            NextTrackControlWidget()
            GameModeControlWidget()
        }
    }
}
